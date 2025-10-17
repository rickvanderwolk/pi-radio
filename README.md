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

```bash
cd pi-radio
./update.sh
```

The update script will:
- Automatically backup and restore your `custom_stations.json` (if it exists)
- Update the `default_stations.json` with the latest stations
- Reinstall dependencies
- Preserve your bookmarks in `config.json`

Note: If the service is running, you may need to restart it after updating:
```bash
sudo systemctl restart pi-radio
```

## Custom Radio Stations

You can add your own radio stations without modifying the default station list.

### Adding Custom Stations

1. Create a `custom_stations.json` file in the project directory:
   ```bash
   cd pi-radio
   cp custom_stations.json.example custom_stations.json
   ```

2. Edit the file and add your stations:
   ```json
   {
     "my_station": "https://example.com/stream.mp3",
     "another_station": "http://radio.example.org/live"
   }
   ```

3. Restart the service (if running):
   ```bash
   sudo systemctl restart pi-radio
   ```

### How It Works

- `default_stations.json` - Contains the default radio stations (updated with each release)
- `custom_stations.json` - Your personal stations (never overwritten during updates)
- Custom stations are merged with default stations at startup
- If a custom station has the same name as a default station, the custom one takes priority
- During updates, `custom_stations.json` is automatically preserved

### Station Format

Each station is a simple key-value pair:
```json
{
  "station_name": "stream_url"
}
```

- Station name should be lowercase with underscores (e.g., `my_favorite_station`)
- URL should be a direct stream URL (usually ends in .mp3, .aac, etc.)

### Finding Stream URLs

Most online radio stations have direct stream URLs. You can often find them:
- On the station's website (look for "Listen" or "Stream" links)
- Using browser developer tools to inspect audio elements
- Searching for "[station name] stream url" online
