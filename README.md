# Pi radio

![Pi-radio](IMG_0492.png)

A Python (Raspberry Pi) script to control online radio streaming with a gamepad. Switch between stations, adjust volume, and manage playback using gamepad buttons.

## Table of Contents

- [Hardware](#hardware)
- [Getting Started](#getting-started)
- [Managing the Service](#managing-the-service)
- [Gamepad Controls](#gamepad-controls)
- [Custom Radio Stations](#custom-radio-stations)
- [Update](#update)

## Hardware

- Raspberry Pi; I use a Pi 4 but any Pi will probably do just fine. Just keep in mind that some models don't have a mini jack (including Pi 5) and normal USB ports. 
- PC speakers; I use cheap PC speakers with a mini jack for audio and USB for power (https://www.bol.com/nl/nl/p/compacte-stereo-luidsprekers-audiocore-ac870-pc-speakers/9200000099727061/) but you can use whatever you like.
- Gamepad; I use a NES style USB gamepad. Something like https://www.amazon.com/Controller-suily-Joystick-RetroPie-Emulators/dp/B07M7SYX11 (They don't have them anymore where I bought them). But any gamepad will do. You might need to change the event types and event codes in `process_event` though.
- Power supply for the Pi
- Power supply for the PC speakers; I recommend using a separate power supply for the PC speakers, as I noticed powering them through one of the USB ports on the Pi resulted in more audio stuttering
- Optional: Case for the Pi; I've used https://www.thingiverse.com/thing:3975417 but you can use any case you want

## Getting Started

1. Install Raspberry Pi OS on a SD card. You can easily choose the right image and setup a username / password, Wi-Fi and enable SSH with the [Raspberry Pi OS imager](https://www.raspberrypi.com/software/). I've used the latest recommended image `Raspberry Pi OS (64-bit) - Release date 2024-07-04 - A port of Debian Bookworm with the Raspberry Pi Desktop` in the example below, but I recommend just installing the latest recommended version.
2. Boot the Pi (might take a while depending on which Pi you're using)
3. Connect via SSH `ssh <your-pi-username>@<your-pi-ip>`
4. Clone repository `git clone https://github.com/rickvanderwolk/pi-radio.git`
5. Run install script `cd pi-radio && bash install.sh`
   - The installer will automatically detect your username and project directory
   - A systemd service will be set up for automatic startup on boot
6. Done! The service is now running. See [Run script](#run-script) below for service management commands.

The installation script will:
- Install all system dependencies (Python, ffmpeg, espeak, pulseaudio)
- Create a virtual environment in the project directory
- Install Python dependencies from requirements.txt
- Set up a systemd service for automatic startup
- Create configuration file from template (config.json)

## Managing the Service

Pi-Radio runs as a systemd service and starts automatically on boot. Use these commands to manage it:

```bash
# Check status
sudo systemctl status pi-radio

# Start service
sudo systemctl start pi-radio

# Stop service
sudo systemctl stop pi-radio

# Restart service
sudo systemctl restart pi-radio

# View logs
journalctl -u pi-radio -f
```

## Update

To update Pi-Radio to the latest version:

```bash
cd pi-radio
bash update.sh
```

The update script will:
- Automatically backup and restore your `custom_stations.json` (if it exists)
- Update the `default_stations.json` with the latest stations
- Reinstall dependencies
- Preserve your configuration in `config.json` (bookmarks and admin settings)

Note: The service will be automatically restarted after the update completes.

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

- `default_stations.json` - Contains the default radio stations (updated with each git pull)
- `custom_stations.json` - Your personal stations (**never modified** by install/update scripts)
- Station merging happens **only in memory** at runtime:
  - Both files are loaded when the app starts
  - Custom stations are combined with default stations
  - If a custom station has the same name as a default station, the custom one takes priority
- During updates, `custom_stations.json` is automatically backed up and restored unchanged

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

## Gamepad Controls

Pi-Radio is controlled entirely via gamepad. Below are all available controls.

### Basic Controls

| Button/Joystick | Action | Description |
|-----------------|--------|-------------|
| **Start** | Play/Pause | Toggle playback of the current station |
| **Joystick Left** | Previous Station | Switch to the previous station in the list |
| **Joystick Right** | Next Station | Switch to the next station in the list |
| **Joystick Up** | Volume Up | Increase system volume |
| **Joystick Down** | Volume Down | Decrease system volume |
| **A Button** | Play Bookmark A | Play the station saved in bookmark A |
| **B Button** | Play Bookmark B | Play the station saved in bookmark B |

### Bookmarks

You can save your favorite stations to two bookmarks (A and B):

**To Save a Bookmark:**
1. Play the station you want to bookmark
2. **Hold down the Select button**
3. **While holding Select, press A or B** (within 10 seconds)
4. The system will confirm via text-to-speech: "Bookmark A set to [station name]"

**To Play a Bookmark:**
- Simply press **A** or **B** to instantly switch to your bookmarked station

Bookmarks are saved in `config.json` and persist across reboots.

### Admin Commands

Pi-Radio includes admin commands for system management. All admin commands require holding the **Select** button while moving the joystick.

| Command | Action | Description |
|---------|--------|-------------|
| **Select + Joystick Up** | Update | Runs `./update.sh` to update Pi-Radio to the latest version |
| **Select + Joystick Right** | Network Info | Speaks the IP address and hostname via TTS |
| **Select + Joystick Left** | Restart App | Restarts the pi-radio service |
| **Select + Joystick Down** | Reboot System | Reboots the entire Raspberry Pi |

**How to Use Admin Commands:**
1. **Hold down the Select button**
2. **While holding Select, move the joystick** in the desired direction
3. **Release both** after the TTS confirmation

The system will speak a confirmation message via text-to-speech before executing each command.

**Requirements:**
- **Update**: Requires `update.sh` script in the project directory
- **Restart App**: Requires sudo privileges for `systemctl restart pi-radio`
- **Reboot System**: Requires sudo privileges for `reboot` command

The pi-radio service runs with appropriate privileges (configured automatically by `install.sh`).

### Configuring Controls

You can customize certain control behaviors by editing `config.json`:

```json
{
  "bookmark_A": null,
  "bookmark_B": null,
  "admin_mode_enabled": true,
  "admin_command_cooldown": 3.0
}
```

- `admin_mode_enabled`: Set to `false` to disable all admin commands via gamepad
- `admin_command_cooldown`: Time in seconds between admin commands (prevents accidental multiple triggers)
- `bookmark_A` / `bookmark_B`: Automatically managed by the system when you save bookmarks

**Note:** Your `config.json` is preserved during updates, so you won't lose your settings or bookmarks.
