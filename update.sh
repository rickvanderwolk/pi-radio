#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting Pi-Radio update...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Backup custom stations if it exists
BACKUP_FILE=""
if [ -f "custom_stations.json" ]; then
    BACKUP_FILE="/tmp/pi-radio-custom-stations-backup-$(date +%s).json"
    echo -e "${YELLOW}Backing up custom_stations.json to ${BACKUP_FILE}${NC}"
    cp custom_stations.json "$BACKUP_FILE"
fi

# Pull latest changes
echo "Pulling latest changes from repository..."
git pull origin main

if [ $? -ne 0 ]; then
    echo "Failed to update the repository."
    # Restore backup if pull failed
    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" custom_stations.json
        echo "Restored custom_stations.json from backup"
        rm "$BACKUP_FILE"
    fi
    exit 1
fi

# Restore custom stations if it was backed up
if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
    echo -e "${GREEN}Restoring custom_stations.json${NC}"
    cp "$BACKUP_FILE" custom_stations.json
    rm "$BACKUP_FILE"
    echo "Custom stations restored successfully"
fi

echo ""
echo "Running install.sh to update dependencies..."

bash install.sh

if [ $? -ne 0 ]; then
    echo "Failed to execute install.sh. Exiting..."
    exit 1
fi

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo ""
echo "Note: Your custom_stations.json has been preserved."
echo "The default_stations.json has been updated with the latest stations."
echo ""

# Check if service is running and restart it
if systemctl is-active --quiet pi-radio; then
    echo "Restarting pi-radio service..."
    sudo systemctl restart pi-radio

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Service restarted successfully!${NC}"
        echo "Check status with: sudo systemctl status pi-radio"
        echo "View logs with: journalctl -u pi-radio -f"
    else
        echo -e "${YELLOW}Warning: Failed to restart service. Please restart manually.${NC}"
    fi
else
    echo -e "${YELLOW}Service is not running. Start it with: sudo systemctl start pi-radio${NC}"
fi

echo ""
