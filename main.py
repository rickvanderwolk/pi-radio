"""
Pi Radio - Gamepad-controlled internet radio player.
"""
import time
import os
import signal
import subprocess
import json
import logging
import shutil
from typing import Optional, Dict
from inputs import get_gamepad
import pyttsx3
import requests

from stations import StationManager
import constants as const

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format=const.LOG_FORMAT,
    datefmt=const.LOG_DATE_FORMAT
)
logger = logging.getLogger(__name__)


class RadioPlayer:
    """Manages radio streaming and playback."""

    def __init__(self, station_manager: StationManager):
        """
        Initialize the RadioPlayer.

        Args:
            station_manager: StationManager instance for accessing stations
        """
        self.station_manager = station_manager
        self.stations = station_manager.get_station_names()
        self.current_station_index = 0
        self.current_process: Optional[subprocess.Popen] = None
        self.tts_engine: Optional[pyttsx3.Engine] = None
        self._init_tts()

    def _init_tts(self):
        """Initialize text-to-speech engine."""
        try:
            self.tts_engine = pyttsx3.init()
            logger.info("Text-to-speech initialized")
        except Exception as e:
            logger.error(f"Failed to initialize text-to-speech: {e}")
            self.tts_engine = None

    def speak(self, text: str):
        """
        Speak text using TTS.

        Args:
            text: Text to speak
        """
        if self.tts_engine is None:
            logger.warning(f"TTS not available, would have said: {text}")
            return

        try:
            self.tts_engine.say(text)
            self.tts_engine.runAndWait()
        except Exception as e:
            logger.error(f"TTS error: {e}")

    def start_stream(self, station_name: str):
        """
        Start streaming a radio station.

        Args:
            station_name: Name of the station to stream
        """
        # Validate station
        stream_url = self.station_manager.get_station_url(station_name)
        if stream_url is None:
            logger.error(f"Station '{station_name}' not found, using default")
            if not self.stations:
                logger.error("No stations available!")
                return
            station_name = self.stations[0]
            stream_url = self.station_manager.get_station_url(station_name)

        # Stop any current stream
        self.stop_stream()

        # Check if ffplay is available
        if shutil.which('ffplay') is None:
            logger.error("ffplay not found! Install ffmpeg to play audio.")
            return

        # Start new stream
        self.speak(f"Starting stream of {station_name}")
        logger.info(f"Starting stream: {station_name} -> {stream_url}")

        command = [
            'ffplay',
            '-autoexit',
            '-nodisp',
            '-rtbufsize', const.FFPLAY_BUFFER_SIZE,
            '-max_delay', const.FFPLAY_MAX_DELAY,
            stream_url
        ]

        try:
            self.current_process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            logger.info(f"Stream started successfully: {station_name}")
        except Exception as e:
            logger.error(f"Failed to start stream: {e}")
            self.current_process = None

    def stop_stream(self):
        """Stop the current stream if playing."""
        if self.current_process is not None:
            try:
                self.current_process.terminate()
                self.current_process.wait(timeout=5)
                logger.info("Stream stopped")
            except subprocess.TimeoutExpired:
                logger.warning("Stream didn't stop gracefully, killing...")
                self.current_process.kill()
            except Exception as e:
                logger.error(f"Error stopping stream: {e}")
            finally:
                self.current_process = None

    def next_station(self):
        """Switch to the next station."""
        if not self.stations:
            logger.error("No stations available")
            return

        self.current_station_index = (self.current_station_index + 1) % len(self.stations)
        self.start_stream(self.stations[self.current_station_index])

    def previous_station(self):
        """Switch to the previous station."""
        if not self.stations:
            logger.error("No stations available")
            return

        self.current_station_index = (self.current_station_index - 1) % len(self.stations)
        self.start_stream(self.stations[self.current_station_index])

    def play_station_by_name(self, station_name: str):
        """
        Play a specific station by name.

        Args:
            station_name: Name of station to play
        """
        if station_name in self.stations:
            self.current_station_index = self.stations.index(station_name)
            self.start_stream(station_name)
        else:
            logger.warning(f"Station '{station_name}' not found")
            self.start_stream(self.stations[0])

    def is_playing(self) -> bool:
        """Check if a stream is currently playing."""
        return self.current_process is not None

    def get_current_station(self) -> Optional[str]:
        """Get the name of the currently playing station."""
        if 0 <= self.current_station_index < len(self.stations):
            return self.stations[self.current_station_index]
        return None


class VolumeController:
    """Manages system volume control."""

    def __init__(self):
        """Initialize the VolumeController."""
        self.amixer_path = shutil.which('amixer')
        if self.amixer_path is None:
            logger.error("amixer not found! Volume control disabled.")

    def adjust(self, direction: str):
        """
        Adjust system volume.

        Args:
            direction: 'up' or 'down'
        """
        if self.amixer_path is None:
            logger.warning("Volume control not available")
            return

        try:
            # Unmute first
            subprocess.call([self.amixer_path, 'set', 'Master', 'unmute'],
                          stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL)

            # Adjust volume
            if direction == "up":
                command = [self.amixer_path, 'set', 'Master', f'{const.VOLUME_STEP}+']
            elif direction == "down":
                command = [self.amixer_path, 'set', 'Master', f'{const.VOLUME_STEP}-']
            else:
                logger.warning(f"Invalid volume direction: {direction}")
                return

            subprocess.call(command,
                          stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL)
            logger.info(f"Volume adjusted: {direction}")
        except Exception as e:
            logger.error(f"Error adjusting volume: {e}")


class BookmarkManager:
    """Manages station bookmarks."""

    def __init__(self, config_file: str):
        """
        Initialize BookmarkManager.

        Args:
            config_file: Path to config file
        """
        self.config_file = config_file
        self.config = self._load_config()

    def _load_config(self) -> Dict:
        """Load configuration from file."""
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    logger.info(f"Config loaded: {config}")
                    return config
            except json.JSONDecodeError as e:
                logger.error(f"Invalid config file: {e}")
            except Exception as e:
                logger.error(f"Error loading config: {e}")

        return {'bookmark_A': None, 'bookmark_B': None}

    def _save_config(self):
        """Save configuration to file."""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
            logger.info(f"Config saved: {self.config}")
        except Exception as e:
            logger.error(f"Error saving config: {e}")

    def set_bookmark(self, bookmark_name: str, station_name: str):
        """
        Set a bookmark to a station.

        Args:
            bookmark_name: 'bookmark_A' or 'bookmark_B'
            station_name: Station to bookmark
        """
        self.config[bookmark_name] = station_name
        self._save_config()
        logger.info(f"{bookmark_name} set to {station_name}")

    def get_bookmark(self, bookmark_name: str) -> Optional[str]:
        """
        Get bookmarked station.

        Args:
            bookmark_name: 'bookmark_A' or 'bookmark_B'

        Returns:
            Station name or None
        """
        return self.config.get(bookmark_name)


class GamepadController:
    """Handles gamepad input and controls the radio."""

    def __init__(self, player: RadioPlayer, volume: VolumeController, bookmarks: BookmarkManager):
        """
        Initialize GamepadController.

        Args:
            player: RadioPlayer instance
            volume: VolumeController instance
            bookmarks: BookmarkManager instance
        """
        self.player = player
        self.volume = volume
        self.bookmarks = bookmarks

        self.last_event_time: Dict[str, float] = {
            const.BUTTON_SELECT: 0,
            const.BUTTON_START: 0,
            const.BUTTON_A: 0,
            const.BUTTON_B: 0,
            const.JOYSTICK_X: 0,
            const.JOYSTICK_Y: 0
        }
        self.select_pressed_time = 0

    def _is_debounced(self, event_code: str) -> bool:
        """
        Check if enough time has passed since last event.

        Args:
            event_code: Event code to check

        Returns:
            True if debounced (enough time passed), False otherwise
        """
        current_time = time.time()
        if current_time - self.last_event_time.get(event_code, 0) > const.DEBOUNCE_TIME:
            self.last_event_time[event_code] = current_time
            return True
        return False

    def _handle_button_select(self):
        """Handle Select button press."""
        self.select_pressed_time = time.time()
        logger.debug("Select button pressed, waiting for A or B...")

    def _handle_button_a(self):
        """Handle A button press."""
        current_time = time.time()

        # Check if this is a bookmark save operation (Select + A)
        if self.select_pressed_time > 0 and current_time - self.select_pressed_time < const.BOOKMARK_SAVE_WINDOW:
            station = self.player.get_current_station()
            if station:
                self.bookmarks.set_bookmark('bookmark_A', station)
                self.player.speak(f"Bookmark A set to {station}")
        else:
            # Play bookmarked station
            station = self.bookmarks.get_bookmark('bookmark_A')
            if station and self.player.station_manager.is_valid_station(station):
                self.player.play_station_by_name(station)
            else:
                logger.info("Bookmark A not set or invalid, playing first station")
                self.player.play_station_by_name(self.player.stations[0])

        self.select_pressed_time = 0

    def _handle_button_b(self):
        """Handle B button press."""
        current_time = time.time()

        # Check if this is a bookmark save operation (Select + B)
        if self.select_pressed_time > 0 and current_time - self.select_pressed_time < const.BOOKMARK_SAVE_WINDOW:
            station = self.player.get_current_station()
            if station:
                self.bookmarks.set_bookmark('bookmark_B', station)
                self.player.speak(f"Bookmark B set to {station}")
        else:
            # Play bookmarked station
            station = self.bookmarks.get_bookmark('bookmark_B')
            if station and self.player.station_manager.is_valid_station(station):
                self.player.play_station_by_name(station)
            else:
                logger.info("Bookmark B not set or invalid, playing first station")
                self.player.play_station_by_name(self.player.stations[0])

        self.select_pressed_time = 0

    def _handle_button_start(self):
        """Handle Start button press (play/pause)."""
        if self.player.is_playing():
            self.player.stop_stream()
        else:
            station = self.player.get_current_station()
            if station:
                self.player.start_stream(station)
            else:
                self.player.start_stream(self.player.stations[0])

    def process_event(self, event):
        """
        Process a gamepad event.

        Args:
            event: Input event from gamepad
        """
        try:
            # Button events
            if event.ev_type == 'Key' and event.state == 1:
                if not self._is_debounced(event.code):
                    return

                if event.code == const.BUTTON_SELECT:
                    self._handle_button_select()
                elif event.code == const.BUTTON_A:
                    self._handle_button_a()
                elif event.code == const.BUTTON_B:
                    self._handle_button_b()
                elif event.code == const.BUTTON_START:
                    self._handle_button_start()

            # Joystick events
            elif event.ev_type == 'Absolute':
                if event.code == const.JOYSTICK_X and self._is_debounced(const.JOYSTICK_X):
                    if event.state < const.JOYSTICK_MIN_THRESHOLD:
                        self.player.previous_station()
                    elif event.state > const.JOYSTICK_MAX_THRESHOLD:
                        self.player.next_station()

                elif event.code == const.JOYSTICK_Y and self._is_debounced(const.JOYSTICK_Y):
                    if event.state < const.JOYSTICK_MIN_THRESHOLD:
                        self.volume.adjust("up")
                    elif event.state > const.JOYSTICK_MAX_THRESHOLD:
                        self.volume.adjust("down")

        except Exception as e:
            logger.error(f"Error processing event: {e}")


def wait_for_network(timeout: int = const.NETWORK_TIMEOUT) -> bool:
    """
    Wait for network connectivity.

    Args:
        timeout: Maximum seconds to wait

    Returns:
        True if network is available, False otherwise
    """
    logger.info("Waiting for network connectivity...")
    start_time = time.time()

    while time.time() - start_time < timeout:
        try:
            requests.get(const.NETWORK_CHECK_URL, timeout=const.NETWORK_REQUEST_TIMEOUT)
            logger.info("Network connectivity established")
            return True
        except requests.ConnectionError:
            logger.debug("Network not available, retrying...")
            time.sleep(const.NETWORK_CHECK_INTERVAL)
        except Exception as e:
            logger.error(f"Network check error: {e}")
            time.sleep(const.NETWORK_CHECK_INTERVAL)

    logger.warning(f"Network not available after {timeout} seconds")
    return False


def setup_signal_handlers(player: RadioPlayer):
    """
    Setup signal handlers for graceful shutdown.

    Args:
        player: RadioPlayer instance to cleanup on shutdown
    """
    def signal_handler(signum, frame):
        logger.info("Shutdown signal received, cleaning up...")
        player.stop_stream()
        exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)


def main():
    """Main entry point."""
    logger.info("Pi Radio starting...")

    # Get base directory
    base_dir = os.path.dirname(os.path.abspath(__file__))

    # Wait for network first
    network_connected = False
    while not network_connected:
        if wait_for_network():
            network_connected = True
        else:
            logger.warning("Retrying network connection...")

    # Initialize components
    try:
        station_manager = StationManager(base_dir)
        player = RadioPlayer(station_manager)
        volume = VolumeController()
        bookmarks = BookmarkManager(os.path.join(base_dir, const.CONFIG_FILE))
        controller = GamepadController(player, volume, bookmarks)
    except Exception as e:
        logger.error(f"Failed to initialize components: {e}")
        return

    # Setup signal handlers
    setup_signal_handlers(player)

    # Start with bookmarked station or first station
    initial_station = bookmarks.get_bookmark('bookmark_A')
    if initial_station and station_manager.is_valid_station(initial_station):
        player.play_station_by_name(initial_station)
    else:
        if player.stations:
            player.start_stream(player.stations[0])
        else:
            logger.error("No stations available to play!")
            return

    # Main event loop
    logger.info("Pi Radio ready, listening for gamepad input...")
    try:
        while True:
            events = get_gamepad()
            for event in events:
                controller.process_event(event)
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    except Exception as e:
        logger.error(f"Fatal error in main loop: {e}")
    finally:
        player.stop_stream()
        logger.info("Pi Radio stopped")


if __name__ == "__main__":
    main()
