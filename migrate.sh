#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
CURRENT_USER="${USER}"

echo -e "${BLUE}Pi-Radio Migration Script${NC}"
echo "================================"
echo ""
echo "This script will upgrade your existing Pi-Radio installation"
echo "to the new structure with improved setup."
echo ""

# Check if old venv exists (in parent directory)
OLD_VENV="${HOME}/pi-radio"
NEW_VENV="${PROJECT_DIR}/.venv"

NEEDS_MIGRATION=false

if [ -d "$OLD_VENV" ]; then
    echo -e "${YELLOW}Found old virtual environment at ${OLD_VENV}${NC}"
    NEEDS_MIGRATION=true
fi

# Check for old crontab entries
if crontab -l 2>/dev/null | grep -q "pi-radio"; then
    echo -e "${YELLOW}Found old crontab entries for pi-radio${NC}"
    NEEDS_MIGRATION=true
fi

# Check if already using new structure
if [ -d "$NEW_VENV" ] && [ -f "/etc/systemd/system/pi-radio.service" ]; then
    echo -e "${GREEN}Already using new structure. Nothing to migrate.${NC}"
    echo ""
    echo "Current service status:"
    sudo systemctl status pi-radio --no-pager || true
    exit 0
fi

if [ "$NEEDS_MIGRATION" = false ]; then
    echo -e "${GREEN}No old installation detected.${NC}"
    echo "You can run ./install.sh for a fresh installation."
    exit 0
fi

echo ""
echo -e "${YELLOW}Migration steps:${NC}"
echo "  1. Backup existing config.json (if exists)"
echo "  2. Remove old virtual environment"
echo "  3. Create new virtual environment in project directory"
echo "  4. Install dependencies"
echo "  5. Remove old crontab entries"
echo "  6. Set up systemd service"
echo ""

read -p "Continue with migration? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}Starting migration...${NC}"
echo ""

# Step 1: Backup config.json if exists
echo -e "${GREEN}[1/6]${NC} Backing up configuration..."
if [ -f "${PROJECT_DIR}/config.json" ]; then
    cp "${PROJECT_DIR}/config.json" "${PROJECT_DIR}/config.json.backup"
    echo "Config backed up to config.json.backup"
else
    echo "No config.json found, skipping backup."
fi

# Step 2: Remove old venv (after confirming)
if [ -d "$OLD_VENV" ]; then
    echo -e "${GREEN}[2/6]${NC} Removing old virtual environment..."
    rm -rf "$OLD_VENV"
    echo "Old virtual environment removed."
else
    echo -e "${GREEN}[2/6]${NC} No old virtual environment to remove."
fi

# Step 3-4: Run install script
echo -e "${GREEN}[3/6]${NC} Running installation script..."
echo ""

# Check if requirements.txt exists
if [ ! -f "${PROJECT_DIR}/requirements.txt" ]; then
    echo -e "${RED}Error: requirements.txt not found!${NC}"
    echo "Please run 'git pull' to get the latest changes first."
    exit 1
fi

# Install system dependencies
echo "Installing system dependencies..."
sudo apt update
sudo apt install -y python3-venv espeak pulseaudio ffmpeg

# Create new venv
echo -e "${GREEN}[4/6]${NC} Creating new virtual environment..."
python3 -m venv "${NEW_VENV}"
source "${NEW_VENV}/bin/activate"

# Install Python packages
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r "${PROJECT_DIR}/requirements.txt"

# Make scripts executable
chmod +x "${PROJECT_DIR}/start_radio.sh"
chmod +x "${PROJECT_DIR}/install.sh"

# Step 5: Remove old crontab entries
echo -e "${GREEN}[5/6]${NC} Checking for old crontab entries..."
if crontab -l 2>/dev/null | grep -q "pi-radio"; then
    echo "Removing old crontab entries..."
    crontab -l 2>/dev/null | grep -v "pi-radio" | crontab - || true
    echo "Old crontab entries removed."
else
    echo "No old crontab entries found."
fi

# Step 6: Set up systemd service
echo -e "${GREEN}[6/6]${NC} Setting up systemd service..."

# Create service file from template
SERVICE_FILE="/tmp/pi-radio.service"
sed "s|%USER%|${CURRENT_USER}|g" "${PROJECT_DIR}/pi-radio.service" | \
sed "s|%PROJECT_DIR%|${PROJECT_DIR}|g" > "${SERVICE_FILE}"

# Install service
sudo cp "${SERVICE_FILE}" /etc/systemd/system/pi-radio.service
sudo systemctl daemon-reload
sudo systemctl enable pi-radio.service

rm "${SERVICE_FILE}"

echo -e "${GREEN}Service installed successfully!${NC}"

echo ""
echo -e "${GREEN}Migration complete!${NC}"
echo ""
echo "Your Pi-Radio installation has been upgraded to the new structure:"
echo "  - Virtual environment: ${NEW_VENV}"
echo "  - Systemd service: enabled"
echo "  - Config preserved: ${PROJECT_DIR}/config.json"
echo ""
echo "Service commands:"
echo "  Start:   sudo systemctl start pi-radio"
echo "  Stop:    sudo systemctl stop pi-radio"
echo "  Status:  sudo systemctl status pi-radio"
echo "  Logs:    journalctl -u pi-radio -f"
echo ""

read -p "Start service now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo systemctl start pi-radio
    echo -e "${GREEN}Service started!${NC}"
    echo ""
    echo "Check status with: sudo systemctl status pi-radio"
else
    echo "You can start it later with: sudo systemctl start pi-radio"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
