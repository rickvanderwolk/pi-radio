"""
Configuration constants for pi-radio.
"""

# Version
__version__ = '1.1.0'

# Debounce timing
DEBOUNCE_TIME = 0.3  # seconds

# Network settings
NETWORK_TIMEOUT = 30  # seconds to wait for network connectivity
NETWORK_CHECK_INTERVAL = 5  # seconds between network check retries
NETWORK_CHECK_URL = 'https://1.1.1.1'  # Cloudflare DNS for network check
NETWORK_REQUEST_TIMEOUT = 5  # seconds for network request timeout

# Bookmark timing
BOOKMARK_SAVE_WINDOW = 10  # seconds - window to save bookmark after Select press

# Volume settings
VOLUME_STEP = '5%'  # Volume adjustment step for amixer

# FFplay settings
FFPLAY_BUFFER_SIZE = '1500M'  # rtbufsize parameter
FFPLAY_MAX_DELAY = '5000000'  # max_delay parameter in microseconds

# Joystick thresholds
JOYSTICK_MIN_THRESHOLD = 100  # Below this = left/up
JOYSTICK_MAX_THRESHOLD = 150  # Above this = right/down

# Button event codes
BUTTON_SELECT = 'BTN_BASE3'
BUTTON_START = 'BTN_BASE4'
BUTTON_A = 'BTN_TRIGGER'
BUTTON_B = 'BTN_THUMB'
JOYSTICK_X = 'ABS_X'
JOYSTICK_Y = 'ABS_Y'

# File paths (relative to project directory)
CONFIG_FILE = 'config.json'
DEFAULT_STATIONS_FILE = 'default_stations.json'
CUSTOM_STATIONS_FILE = 'custom_stations.json'
UPDATE_SCRIPT = 'update.sh'

# Service settings
SERVICE_NAME = 'pi-radio'

# Logging
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
LOG_DATE_FORMAT = '%Y-%m-%d %H:%M:%S'
