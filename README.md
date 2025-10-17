# Pi radio

![Pi-radio](IMG_0492.png)

A Python (Raspberry Pi) script to control online radio streaming with a gamepad. Switch between stations, adjust volume, and manage playback using gamepad buttons.

- [Hardware](#hardware)
- [Getting started](#getting-started)
- [Run script](#run-script)
- [Update](#update)

<a id="hardware"></a>
## Hardware

- Raspberry Pi; I use a Pi 4 but any Pi will probably do just fine. Just keep in mind that some models don't have a mini jack (including Pi 5) and normal USB ports. 
- PC speakers; I use cheap PC speakers with a mini jack for audio and USB for power (https://www.bol.com/nl/nl/p/compacte-stereo-luidsprekers-audiocore-ac870-pc-speakers/9200000099727061/) but you can use whatever you like.
- Gamepad; I use a NES style USB gamepad. Something like https://www.amazon.com/Controller-suily-Joystick-RetroPie-Emulators/dp/B07M7SYX11 (They don't have them anymore where I bought them). But any gamepad will do. You might need to change the event types and event codes in `process_event` though.
- Power supply for the Pi
- Power supply for the PC speakers; I recommend using a separate power supply for the PC speakers, as I noticed powering them through one of the USB ports on the Pi resulted in more audio stuttering
- Optional: Case for the Pi; I've used https://www.thingiverse.com/thing:3975417 but you can use any case you want

<a id="#getting-started"></a>
## Getting started

## Fresh Installation

1. Install Raspberry Pi OS on a SD card. You can easily choose the right image and setup a username / password, Wi-Fi and enable SSH with the [Raspberry Pi OS imager](https://www.raspberrypi.com/software/). I've used the latest recommended image `Raspberry Pi OS (64-bit) - Release date 2024-07-04 - A port of Debian Bookworm with the Raspberry Pi Desktop` in the example below, but I recommend just installing the latest recommended version.
2. Boot the Pi (might take a while depending on which Pi you're using)
3. Connect via SSH `ssh <your-pi-username>@<your-pi-ip>`
4. Clone repository `git clone https://github.com/rickvanderwolk/pi-radio.git`
5. Run install script `cd pi-radio && ./install.sh`
   - The installer will automatically detect your username and project directory
   - You'll be prompted whether to install as a systemd service (recommended)
   - If you choose yes, Pi-Radio will start automatically on boot
6. Done! If you installed the service, it's already running. Otherwise, see [Run script](#run-script) below.

The installation script will:
- Install all system dependencies (Python, ffmpeg, espeak, pulseaudio)
- Create a virtual environment in the project directory
- Install Python dependencies from requirements.txt
- Optionally set up a systemd service for automatic startup

<a id="#run-script"></a>
## Run script

### With systemd service (recommended)

If you installed the systemd service during installation:

```bash
# Check status
sudo systemctl status pi-radio

# Start manually
sudo systemctl start pi-radio

# Stop
sudo systemctl stop pi-radio

# Restart
sudo systemctl restart pi-radio

# View logs
journalctl -u pi-radio -f
```

### Manual run

If you prefer to run manually without the service:

```bash
cd pi-radio
./start_radio.sh
```

<a id="#update"></a>
## Migrating from Old Installation

If you're using an old version of this project with the manual username replacement setup:

1. Pull latest changes `cd pi-radio && git pull`
2. Run migration script `./migrate.sh`
   - Automatically detects and removes old virtual environment
   - Removes old crontab entries
   - Sets up new systemd service
   - Preserves your config.json bookmarks

The migration script handles everything automatically - no manual steps needed!

## Update (Existing New Installation)

If you're already using the new installation setup and want to update:

1. Stop the service (if running): `sudo systemctl stop pi-radio`
2. Pull latest changes: `cd pi-radio && git pull`
3. Reinstall dependencies: `./install.sh`
4. Start the service: `sudo systemctl start pi-radio`
