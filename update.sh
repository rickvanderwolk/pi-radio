#!/bin/bash

echo "Starting update..."

cd ~/pi-radio

if [ $? -ne 0 ]; then
    echo "Failed to change directory to ~/pi-radio. Exiting..."
    exit 1
fi

git pull origin main

if [ $? -ne 0 ]; then
    echo "Failed to update the repository. Exiting..."
    exit 1
fi

echo "Running install.sh..."

bash install.sh

if [ $? -ne 0 ]; then
    echo "Failed to execute install.sh. Exiting..."
    exit 1
fi

echo "install.sh executed successfully."

echo "Update complete."
