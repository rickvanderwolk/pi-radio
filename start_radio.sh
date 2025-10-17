#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Start pulseaudio if not running
pulseaudio --check || pulseaudio --start

# Activate virtual environment
source "${SCRIPT_DIR}/.venv/bin/activate"

# Run the application
python "${SCRIPT_DIR}/main.py"
