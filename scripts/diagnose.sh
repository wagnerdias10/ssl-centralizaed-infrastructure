#!/bin/bash
# Complete diagnostic script for centralized SSL infrastructure

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== COMPLETE SSL INFRASTRUCTURE DIAGNOSIS ===${NC}"
echo "Started at: $(date)"
echo ""

# 1. Check basic services
echo -e "${BLUE}1. Checking basic services...${NC}"
services=("nginx" "systemd-resolved")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo -e "   ${GREEN}✅ $service is running${NC}"
    else
        echo -e "   ${RED}❌ $service is NOT running${NC}"
    fi
done

# 2. Check ports
echo -e "${BLUE}2. Checking ports...${NC}"
ports=("80" "443")
for port in "${ports[@]}"; do
    if sudo netstat -tlnp | grep -q ":$port "; then
        echo -e "   ${GREEN}✅ Port $port is in use${NC}"
    else
        echo -e "   ${RED}❌ Port $port is NOT in use${NC}"
    fi
done

# 3. Check certificate file existence
echo -e "${BLUE}3. Checking certificate files...${NC}"
cert_files=(
    "/etc/nginx/ssl/wildcard.example.local.crt"
    "/etc/nginx/ssl/wildcard.example.local.key"
    "/etc/nginx/ssl/wildcard_chain.crt"
    "/etc/ssl/private/ca/rootCA.crt"
    "/etc/ssl/private/ca/intermediateCA.crt"
    "/etc/nginx/ssl/dhparam.pem"
)

for file in "${cert_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "   ${GREEN}✅ $(basename "$file") exists${NC}"
    else
        echo -e "   ${RED}❌ $(basename "$file") NOT found${NC}"
    fi
done

# 4. Check certificate validity
echo -e "${BLUE}4. Checking certificate validity...${NC}"
check_cert_validity() {
    local cert_file=$1
    local cert_name=$2
    
    if [ -f "$cert_file" ]; then
        local expiry_date=$(sudo openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
        
        if [ $days_left -gt 30 ]; then
            echo -e "   ${GREEN}✅ $cert_name: $days_left days remaining${NC}"
        elif [ $days_left -gt 7 ]; then
            echo -e "   ${YELLOW}⚠️ $cert_name: $days_left days remaining (WARNING)${NC}"
        else
            echo -e "   ${RED}❌ $cert_name: $days_left days remaining (CRITICAL)${NC}"
        fi
    else
        echo -e "   ${RED}❌ $cert_name: File NOT found${NC}"
    fi
}

check_cert_validity "/etc/nginx/ssl/wildcard.example.local.crt" "Wildcard Certificate"
check_cert_validity "/etc/ssl/private/ca/intermediateCA.crt" "Intermediate CA"
check_cert_validity "/etc/ssl/private/ca/rootCA.crt" "Root CA"

# 5. Test NGINX configuration
echo -e "${BLUE}5. Testing NGINX configuration...${NC}"
if sudo nginx -t &>/dev/null; then
    echo -e "   ${GREEN}✅ NGINX configuration is valid${NC}"
else
    echo -e "   ${RED}❌ NGINX configuration error${NC}"
fi

# 6. Check backend connectivity
echo -e "${BLUE}6. Testing backend connectivity...${NC}"
if timeout 5 bash -c "</dev/tcp/192.168.204.137/8081" 2>/dev/null; then
    echo -e "   ${GREEN}✅ Jenkins (192.168.204.137:8081) accessible${NC}"
else
    echo -e "   ${RED}❌ Jenkins (192.168.204.137:8081) - NOT accessible${NC}"
fi

# 7. Check DNS resolution
echo -e "${BLUE}7. Testing DNS resolution...${NC}"
domains=("jenkins.example.local" "nginx.example.local" "dashboard.example.local")
for domain in "${domains[@]}"; do
    if nslookup "$domain" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ $domain resolves correctly${NC}"
    else
        echo -e "   ${RED}❌ $domain does NOT resolve${NC}"
    fi
done

# 8. Check recent NGINX logs
echo -e "${BLUE}8. Checking recent NGINX logs...${NC}"
error_count=$(find /var/log/nginx/ -name "*.log" -mtime -1 -exec sudo grep -c "error" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
if [ "$error_count" -gt 0 ]; then
    echo -e "   ${YELLOW}⚠️ $error_count errors found in logs in the last 24h${NC}"
else
    echo -e "   ${GREEN}✅ No significant errors in logs${NC}"
fi

# 9. Check system resources
echo -e "${BLUE}9. Checking system resources...${NC}"
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
disk_usage=$(df -h / | awk 'NR==2{print $5}' | cut -d'%' -f1)

echo "   CPU: ${cpu_usage}%"
echo "   Memory: ${mem_usage}%"
echo "   Disk: ${disk_usage}%"

echo ""
echo -e "${BLUE}=== END OF DIAGNOSIS ===${NC}"