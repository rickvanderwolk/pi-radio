#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo -e "${GREEN}Pi-Radio Installation${NC}"
echo "================================"
echo ""

# Detect username automatically
CURRENT_USER="${USER}"
echo -e "Installing for user: ${GREEN}${CURRENT_USER}${NC}"
echo -e "Project directory: ${GREEN}${PROJECT_DIR}${NC}"
echo ""

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null && ! grep -q "BCM" /proc/cpuinfo 2>/dev/null; then
    echo -e "${YELLOW}Warning: This doesn't appear to be a Raspberry Pi. Continuing anyway...${NC}"
fi

# Install system dependencies
echo -e "${GREEN}[1/6]${NC} Installing system dependencies..."
sudo apt update
sudo apt install -y python3-venv espeak pulseaudio ffmpeg

if ! command -v ffplay &> /dev/null; then
    echo -e "${RED}Error: ffplay not installed. Please install ffmpeg.${NC}"
    exit 1
fi

# Create virtual environment in project directory
echo -e "${GREEN}[2/6]${NC} Creating virtual environment..."
if [ -d "${PROJECT_DIR}/.venv" ]; then
    echo -e "${YELLOW}Virtual environment already exists. Skipping creation.${NC}"
else
    python3 -m venv "${PROJECT_DIR}/.venv"
    echo "Virtual environment created at ${PROJECT_DIR}/.venv"
fi

# Activate virtual environment
echo -e "${GREEN}[3/6]${NC} Activating virtual environment..."
source "${PROJECT_DIR}/.venv/bin/activate"

# Install Python dependencies from requirements.txt
echo -e "${GREEN}[4/6]${NC} Installing Python dependencies..."
if [ -f "${PROJECT_DIR}/requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r "${PROJECT_DIR}/requirements.txt"
else
    echo -e "${RED}Error: requirements.txt not found!${NC}"
    exit 1
fi

# Check station files
echo ""
echo "Checking station configuration files..."
if [ ! -f "${PROJECT_DIR}/default_stations.json" ]; then
    echo -e "${RED}Error: default_stations.json not found!${NC}"
    exit 1
fi

# Create custom_stations.json.example if it doesn't exist
if [ ! -f "${PROJECT_DIR}/custom_stations.json.example" ]; then
    echo -e "${YELLOW}Warning: custom_stations.json.example not found!${NC}"
fi

# Inform user about custom stations
if [ ! -f "${PROJECT_DIR}/custom_stations.json" ]; then
    echo -e "${YELLOW}No custom stations file found.${NC}"
    echo "To add your own stations:"
    echo "  1. Create custom_stations.json in ${PROJECT_DIR}"
    echo "  2. Add your stations in JSON format: {\"name\": \"url\"}"
    echo "  3. See custom_stations.json.example for reference"
else
    echo -e "${GREEN}Custom stations file found: custom_stations.json${NC}"
fi

# Make start script executable
echo -e "${GREEN}[5/6]${NC} Setting up start script..."
chmod +x "${PROJECT_DIR}/start_radio.sh"

# Ask about systemd service installation
echo ""
echo -e "${GREEN}[6/6]${NC} Systemd service setup"
echo "Would you like to install Pi-Radio as a systemd service?"
echo "This will make it start automatically on boot."
read -p "Install service? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing systemd service..."

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
    fi
else
    echo "Skipping service installation."
    echo "You can run manually with: ${PROJECT_DIR}/start_radio.sh"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Connect your gamepad"
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "  2. Run: ${PROJECT_DIR}/start_radio.sh"
else
    echo "  2. Check status: sudo systemctl status pi-radio"
fi
echo ""
