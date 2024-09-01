#!/bin/bash
pulseaudio --start
source /home/<your-pi-username>/pi-radio/bin/activate
python /home/<your-pi-username>/pi-radio/main.py
