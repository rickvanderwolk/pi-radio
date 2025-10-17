#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Pi-Radio update...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create backup directory with timestamp
BACKUP_DIR="${SCRIPT_DIR}/.backups/update-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backup directory: ${BACKUP_DIR}"
echo ""

# Backup custom stations if it exists
if [ -f "custom_stations.json" ]; then
    echo -e "${YELLOW}Backing up custom_stations.json${NC}"
    cp custom_stations.json "$BACKUP_DIR/custom_stations.json"
fi

# Backup config.json if it exists
if [ -f "config.json" ]; then
    echo -e "${YELLOW}Backing up config.json${NC}"
    cp config.json "$BACKUP_DIR/config.json"
fi

echo ""

# Detect current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: ${CURRENT_BRANCH}"

# Pull latest changes from current branch
echo "Pulling latest changes from origin/${CURRENT_BRANCH}..."
if ! git pull origin "$CURRENT_BRANCH"; then
    echo -e "${RED}Failed to update the repository.${NC}"
    echo "Restoring backups..."

    # Restore backups
    if [ -f "$BACKUP_DIR/custom_stations.json" ]; then
        cp "$BACKUP_DIR/custom_stations.json" custom_stations.json
        echo "Restored custom_stations.json"
    fi

    if [ -f "$BACKUP_DIR/config.json" ]; then
        cp "$BACKUP_DIR/config.json" config.json
        echo "Restored config.json"
    fi

    exit 1
fi

echo ""

# Restore custom stations if it was backed up
if [ -f "$BACKUP_DIR/custom_stations.json" ]; then
    echo -e "${GREEN}Restoring custom_stations.json${NC}"
    cp "$BACKUP_DIR/custom_stations.json" custom_stations.json
fi

# Merge config.json - preserve user values, add new defaults
if [ -f "$BACKUP_DIR/config.json" ] && [ -f "config.json.example" ]; then
    echo -e "${GREEN}Merging config.json with new defaults${NC}"

    # Use Python to merge JSON files
    python3 <<PYTHON_MERGE
import json
import sys
import os

backup_config = "${BACKUP_DIR}/config.json"

try:
    # Load existing config (backup)
    with open(backup_config, 'r') as f:
        user_config = json.load(f)

    # Load example config with new defaults
    with open('config.json.example', 'r') as f:
        example_config = json.load(f)

    # Merge: user values take precedence, but add new keys from example
    merged_config = {**example_config, **user_config}

    # Save merged config
    with open('config.json', 'w') as f:
        json.dump(merged_config, f, indent=2)

    print("Config merged successfully")
    sys.exit(0)
except Exception as e:
    print(f"Error merging config: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_MERGE

    if [ $? -eq 0 ]; then
        echo "✓ Config updated with new defaults while preserving your settings"
    else
        echo -e "${YELLOW}Warning: Could not merge config, restoring backup${NC}"
        cp "$BACKUP_DIR/config.json" config.json
    fi
elif [ -f "$BACKUP_DIR/config.json" ]; then
    # No example file, just restore backup
    echo -e "${GREEN}Restoring config.json${NC}"
    cp "$BACKUP_DIR/config.json" config.json
fi

echo ""

echo ""
echo "Running install.sh to update dependencies..."

# Run install.sh (fully automatic, no prompts)
bash install.sh

if [ $? -ne 0 ]; then
    echo "Failed to execute install.sh. Exiting..."
    exit 1
fi

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo ""
echo "✓ Your config.json and custom_stations.json have been preserved"
echo "✓ New config options have been added automatically"
echo "✓ The default_stations.json has been updated with the latest stations"
echo ""
echo -e "${YELLOW}Backups saved to: ${BACKUP_DIR}${NC}"
echo ""

# Check if service is running and restart it
if systemctl is-active --quiet pi-radio; then
    echo "Restarting pi-radio service..."
    sudo systemctl restart pi-radio

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Service restarted successfully!${NC}"
        echo ""
        echo "Check status: sudo systemctl status pi-radio"
        echo "View logs: journalctl -u pi-radio -f"
    else
        echo -e "${YELLOW}Warning: Failed to restart service. Please restart manually.${NC}"
    fi
else
    echo -e "${YELLOW}Service is not running. Start it with: sudo systemctl start pi-radio${NC}"
fi

echo ""
