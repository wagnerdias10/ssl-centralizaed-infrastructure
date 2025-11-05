#!/bin/bash
# Infrastructure status script for centralized SSL infrastructure

echo "=== CENTRALIZED SSL INFRASTRUCTURE STATUS ==="
echo "Date: $(date)"
echo ""

# 1. NGINX Status
echo "1. NGINX:"
if systemctl is-active --quiet nginx; then
    echo "   ✅ NGINX is running"
else
    echo "   ❌ NGINX is NOT running"
fi

# 2. NGINX Configuration
echo "2. NGINX Configuration:"
if sudo nginx -t &>/dev/null; then
    echo "   ✅ Configuration is valid"
else
    echo "   ❌ NGINX configuration error"
fi

# 3. Certificates
echo "3. Certificates:"
check_cert() {
    local cert_file=$1
    local cert_name=$2
    
    if [ -f "$cert_file" ]; then
        local expiry_date=$(sudo openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
        
        if [ $days_left -gt 30 ]; then
            echo "   ✅ $cert_name: $days_left days remaining"
        elif [ $days_left -gt 7 ]; then
            echo "   ⚠️ $cert_name: $days_left days remaining (WARNING)"
        else
            echo "   ❌ $cert_name: $days_left days remaining (CRITICAL)"
        fi
    else
        echo "   ❌ $cert_name: File NOT found"
    fi
}

check_cert "/etc/nginx/ssl/wildcard.example.local.crt" "Wildcard Certificate"
check_cert "/etc/ssl/private/ca/intermediateCA.crt" "Intermediate CA"
check_cert "/etc/ssl/private/ca/rootCA.crt" "Root CA"

# 4. Backend connectivity
echo "4. Backend Connectivity:"
if timeout 3 bash -c "</dev/tcp/192.168.204.137/8081" 2>/dev/null; then
    echo "   ✅ Jenkins (192.168.204.137:8081) accessible"
else
    echo "   ❌ Jenkins (192.168.204.137:8081) - NOT accessible"
fi

echo ""
echo "=== END OF REPORT ==="