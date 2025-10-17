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

# ============================================================================
# MIGRATION: Detect and cleanup old setup (one-time, automatic)
# ============================================================================
if [ -d "${PROJECT_DIR}/pi-radio" ] && [ -f "${PROJECT_DIR}/pi-radio/bin/activate" ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Old pi-radio setup detected - Starting automatic migration...${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Stop old processes
    echo -e "${YELLOW}[Migration 1/3]${NC} Stopping old processes..."
    if pkill -f "python.*main.py" 2>/dev/null; then
        echo "  ✓ Stopped old Python process"
    else
        echo "  ○ No old Python process found"
    fi

    if pkill -f "start_radio.sh" 2>/dev/null; then
        echo "  ✓ Stopped start_radio.sh process"
    else
        echo "  ○ No start_radio.sh process found"
    fi

    # Remove cron jobs
    echo ""
    echo -e "${YELLOW}[Migration 2/3]${NC} Checking cron jobs..."
    if crontab -l 2>/dev/null | grep -q -E "(pi-radio|start_radio\.sh)"; then
        echo "  Found old pi-radio cron jobs, removing..."
        crontab -l 2>/dev/null | grep -v "pi-radio" | grep -v "start_radio.sh" | crontab - 2>/dev/null
        echo "  ✓ Cron jobs cleaned"
    else
        echo "  ○ No pi-radio cron jobs found"
    fi

    # Remove old venv
    echo ""
    echo -e "${YELLOW}[Migration 3/3]${NC} Removing old virtual environment..."
    rm -rf "${PROJECT_DIR}/pi-radio"
    echo "  ✓ Old venv directory removed (${PROJECT_DIR}/pi-radio/)"

    echo ""
    echo -e "${GREEN}✓ Migration complete!${NC}"
    echo -e "${GREEN}  Your system is now ready for the new systemd-based setup.${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
fi

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null && ! grep -q "BCM" /proc/cpuinfo 2>/dev/null; then
    echo -e "${YELLOW}Warning: This doesn't appear to be a Raspberry Pi. Continuing anyway...${NC}"
fi

# Install system dependencies
echo -e "${GREEN}[1/5]${NC} Installing system dependencies..."
sudo apt update
sudo apt install -y python3-venv espeak pulseaudio ffmpeg

if ! command -v ffplay &> /dev/null; then
    echo -e "${RED}Error: ffplay not installed. Please install ffmpeg.${NC}"
    exit 1
fi

# Create virtual environment in project directory
echo -e "${GREEN}[2/5]${NC} Creating virtual environment..."
if [ -d "${PROJECT_DIR}/.venv" ]; then
    echo -e "${YELLOW}Virtual environment already exists. Skipping creation.${NC}"
else
    python3 -m venv "${PROJECT_DIR}/.venv"
    echo "Virtual environment created at ${PROJECT_DIR}/.venv"
fi

# Activate virtual environment
echo -e "${GREEN}[3/5]${NC} Activating virtual environment..."
source "${PROJECT_DIR}/.venv/bin/activate"

# Install Python dependencies from requirements.txt
echo -e "${GREEN}[4/5]${NC} Installing Python dependencies..."
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

# Setup config.json from example if it doesn't exist
echo ""
echo "Checking configuration file..."
if [ ! -f "${PROJECT_DIR}/config.json" ]; then
    if [ -f "${PROJECT_DIR}/config.json.example" ]; then
        cp "${PROJECT_DIR}/config.json.example" "${PROJECT_DIR}/config.json"
        echo -e "${GREEN}Created config.json from example${NC}"
    else
        echo -e "${YELLOW}Warning: config.json.example not found, config will be created automatically on first run${NC}"
    fi
else
    echo -e "${GREEN}Configuration file found: config.json${NC}"
fi

# Setup systemd service (always)
echo ""
echo -e "${GREEN}[5/5]${NC} Systemd service setup"
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

# Check if service is already running
if systemctl is-active --quiet pi-radio; then
    echo "Service is already running, restart will be handled by update script."
else
    # Start service automatically
    echo "Starting service..."
    sudo systemctl start pi-radio
    echo -e "${GREEN}Service started!${NC}"
fi

echo ""
echo "Service commands:"
echo "  Status:  sudo systemctl status pi-radio"
echo "  Stop:    sudo systemctl stop pi-radio"
echo "  Restart: sudo systemctl restart pi-radio"
echo "  Logs:    journalctl -u pi-radio -f"
echo ""

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Connect your gamepad"
echo "  2. Check status: sudo systemctl status pi-radio"
echo "  3. View logs: journalctl -u pi-radio -f"
echo ""
