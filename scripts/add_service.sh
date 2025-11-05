#!/bin/bash
# Script to add new services to NGINX centralized SSL infrastructure

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Add New Service to NGINX Reverse Proxy ===${NC}"

# Check if correct number of arguments was provided
if [ $# -ne 3 ]; then
    echo -e "${RED}❌ Incorrect usage.${NC}"
    echo "Usage: $0 <service_name> <backend_ip> <backend_port>"
    echo "Example: $0 gitlab 192.168.204.135 8080"
    exit 1
fi

SERVICE_NAME=$1
BACKEND_IP=$2
BACKEND_PORT=$3

echo -e "${GREEN}Adding service: ${SERVICE_NAME}.example.local -> ${BACKEND_IP}:${BACKEND_PORT}${NC}"

# 1. Validate parameters
echo "1. Validating parameters..."
if [[ ! $SERVICE_NAME =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo -e "${RED}❌ Error: Service name must contain only letters, numbers, and hyphens.${NC}"
    exit 1
fi

if [[ ! $BACKEND_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}❌ Error: Invalid backend IP.${NC}"
    exit 1
fi

if [[ ! $BACKEND_PORT =~ ^[0-9]+$ ]] || [ $BACKEND_PORT -lt 1 ] || [ $BACKEND_PORT -gt 65535 ]; then
    echo -e "${RED}❌ Error: Backend port must be a number between 1 and 65535.${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ Parameters are valid.${NC}"

# 2. Check if service already exists
echo "2. Checking if service ${SERVICE_NAME} already exists..."
if [ -f "/etc/nginx/sites-available/${SERVICE_NAME}.example.local.conf" ]; then
    echo -e "${RED}❌ Error: Service '${SERVICE_NAME}' already exists.${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ Service '${SERVICE_NAME}' doesn't exist, proceeding.${NC}"

# 3. Test backend connectivity
echo "3. Testing connectivity to backend ${BACKEND_IP}:${BACKEND_PORT}..."
if ! timeout 5 bash -c "</dev/tcp/$BACKEND_IP/$BACKEND_PORT" 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Warning: Could not connect to backend ${BACKEND_IP}:${BACKEND_PORT}.${NC}"
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Operation cancelled by user.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}   ✅ Backend connectivity OK.${NC}"
fi

# 4. Create configuration from template
echo "4. Creating configuration file from template..."
TEMPLATE_PATH="/opt/ssl-management/templates/service_template.conf"
CONFIG_FILE_TMP="/tmp/${SERVICE_NAME}.example.local.conf.tmp"
CONFIG_FILE_FINAL="/etc/nginx/sites-available/${SERVICE_NAME}.example.local.conf"
SYMLINK_FILE="/etc/nginx/sites-enabled/${SERVICE_NAME}.example.local.conf"

if [ ! -f "$TEMPLATE_PATH" ]; then
    echo -e "${RED}❌ Error: Template not found at '$TEMPLATE_PATH'.${NC}"
    exit 1
fi

cp "$TEMPLATE_PATH" "$CONFIG_FILE_TMP"
sed -i "s/SERVICE_NAME/${SERVICE_NAME}/g" "$CONFIG_FILE_TMP"
sed -i "s/BACKEND_IP/${BACKEND_IP}/g" "$CONFIG_FILE_TMP"
sed -i "s/BACKEND_PORT/${BACKEND_PORT}/g" "$CONFIG_FILE_TMP"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Template processed successfully.${NC}"
else
    echo -e "${RED}❌ Error processing template.${NC}"
    rm -f "$CONFIG_FILE_TMP"
    exit 1
fi

# 5. Move to correct location and create symbolic link
echo "5. Moving configuration and creating symbolic link..."
mv "$CONFIG_FILE_TMP" "$CONFIG_FILE_FINAL"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error moving configuration file.${NC}"
    exit 1
fi

ln -s "$CONFIG_FILE_FINAL" "$SYMLINK_FILE"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error creating symbolic link.${NC}"
    rm -f "$CONFIG_FILE_FINAL"
    exit 1
fi
echo -e "${GREEN}   ✅ Configuration file and symbolic link created.${NC}"

# 6. Create logs directory
echo "6. Creating logs directory for the service..."
mkdir -p /var/log/nginx/sites
echo -e "${GREEN}   ✅ Logs directory ensured.${NC}"

# 7. Test NGINX configuration and reload
echo "7. Testing NGINX configuration..."
if sudo nginx -t; then
    echo -e "${GREEN}   ✅ NGINX configuration valid. Reloading NGINX...${NC}"
    sudo systemctl reload nginx
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✅ NGINX reloaded successfully!${NC}"
        echo ""
        echo -e "${GREEN}Service '${SERVICE_NAME}.example.local' added successfully! 🎉${NC}"
        echo ""
        echo -e "${BLUE}IMPORTANT next steps:${NC}"
        echo "1. Add DNS record on Windows Server: ${SERVICE_NAME}.example.local -> 192.168.204.139"
        echo "2. Configure backend service at ${BACKEND_IP}:${BACKEND_PORT}"
        echo "3. Test access via browser: https://${SERVICE_NAME}.example.local"
        echo "4. Check logs: tail -f /var/log/nginx/sites/${SERVICE_NAME}.access.log"
    else
        echo -e "${RED}❌ Error reloading NGINX.${NC}"
        rm -f "$CONFIG_FILE_FINAL"
        rm -f "$SYMLINK_FILE"
        exit 1
    fi
else
    echo -e "${RED}❌ NGINX configuration error. Removing created files...${NC}"
    rm -f "$CONFIG_FILE_FINAL"
    rm -f "$SYMLINK_FILE"
    exit 1
fi