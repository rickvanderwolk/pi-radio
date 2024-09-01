#!/bin/bash

echo "Starting update..."

cd ~/led-sort

if [ $? -ne 0 ]; then
    echo "Failed to change directory to ~/led-sort. Exiting..."
    exit 1
fi

git pull origin main

if [ $? -ne 0 ]; then
    echo "Failed to update the repository. Exiting..."
    exit 1
fi

echo "Update complete."
