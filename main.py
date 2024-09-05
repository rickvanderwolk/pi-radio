import time
import os
import signal
import subprocess
import json
from inputs import get_gamepad
import pyttsx3

DEBOUNCE_TIME = 0.3

last_event_time = {
    'BTN_BASE3': 0,  # Select button
    'BTN_BASE4': 0,  # Start button
    'BTN_TRIGGER': 0,  # Button A
    'BTN_THUMB': 0,  # Button B
    'ABS_X': 0,  # Joystick left / right
    'ABS_Y': 0   # Joystick up / down
}

radio_stations = {
    'inthahouse': 'https://ex52.voordeligstreamen.nl/8056/stream',
    'sublime': 'https://stream.sublime.nl/web21_mp3?dist=sublime_website',
    'radio4': 'https://icecast.omroep.nl/radio4-bb-mp3',
    '1000_hits_love': 'https://ais-sa2.cdnstream1.com/2210_128.mp3',
    '538_radio': 'https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO538.mp3',
    '538_dancedepartment': 'https://playerservices.streamtheworld.com/api/livestream-redirect/TLPSTR01.mp3',
    '538_hitzone': 'https://playerservices.streamtheworld.com/api/livestream-redirect/TLPSTR11.mp3',
    '538_nonstop': 'https://playerservices.streamtheworld.com/api/livestream-redirect/TLPSTR09.mp3',
    '538_top50': 'https://playerservices.streamtheworld.com/api/livestream-redirect/TLPSTR13.mp3',
    'qmusic': 'https://stream.qmusic.nl/qmusic/mp3',
    'qnonstop': 'https://stream.qmusic.nl/nonstop/mp3',
    'skyradio_nonstop': 'https://25583.live.streamtheworld.com/SKYRADIO.mp3',
    'slam': 'https://stream.slam.nl/slam_mp3',
    'slam_mixmarathon': 'https://stream.slam.nl/web13_mp3',
    'slam_nonstop': 'https://stream.slam.nl/web10_mp3',
    'slam_the_boom_room': 'https://stream.slam.nl/web12_mp3',
    'slam_hardstyle': 'https://stream.slam.nl/web11_mp3',
    'slam_housuh_in_de_pauzuh': 'https://stream.slam.nl/web16_mp3',
    'cadena_digital': 'http://185.23.192.118:8006/;stream.mp3',
    'dnbradio': 'https://azrelay.drmnbss.org/listen/dnbradio/radio.mp3',
}

stations = list(radio_stations.keys())
current_station_index = 0
current_process = None
config_file = os.path.join(os.path.dirname(__file__), 'config.json')
select_pressed_time = 0

def speak_text(text):
    engine = pyttsx3.init()
    engine.say(text)
    engine.runAndWait()

def load_config():
    if os.path.exists(config_file):
        with open(config_file, 'r') as file:
            return json.load(file)
    else:
        return {'bookmark_A': None, 'bookmark_B': None}

def save_config(config):
    with open(config_file, 'w') as file:
        json.dump(config, file)

def start_stream(station):
    global current_process
    if station not in radio_stations:
        print(f"Station '{station}' is not valid. Starting default station.")
        station = stations[0]
    stop_stream()
    speak_text(f"Starting stream of {station}")
    stream_url = radio_stations[station]
    command = ['ffplay', '-autoexit', '-nodisp', '-rtbufsize', '1500M', '-max_delay', '5000000', stream_url]
    current_process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    print(f"Streaming audio van {station}... Druk op Ctrl+C om te stoppen.")

def stop_stream():
    global current_process
    if current_process is not None:
        current_process.terminate()
        current_process.wait()
        current_process = None
        print("Stream gestopt.")

def adjust_volume(direction):
    amixer_path = '/usr/bin/amixer'
    subprocess.call([amixer_path, 'set', 'Master', 'unmute'])

    if direction == "up":
        command = [amixer_path, 'set', 'Master', '5%+']
    elif direction == "down":
        command = [amixer_path, 'set', 'Master', '5%-']

    subprocess.call(command)
    print(f"Volume {direction}")

def process_event(event):
    global current_station_index, select_pressed_time
    current_time = time.time()

    if event.ev_type == 'Key' and event.state == 1 and current_time - last_event_time.get(event.code, 0) > DEBOUNCE_TIME:
        if event.code == 'BTN_BASE3':
            select_pressed_time = current_time
            print("Select button pressed, waiting for A or B...")
            last_event_time['BTN_BASE3'] = current_time
        elif event.code in ['BTN_TRIGGER', 'BTN_THUMB']:
            if select_pressed_time > 0 and current_time - select_pressed_time < 10:
                button = 'bookmark_A' if event.code == 'BTN_TRIGGER' else 'bookmark_B'
                config[button] = stations[current_station_index]
                save_config(config)
                print(f"Station {stations[current_station_index]} gekoppeld aan {button}.")
            else:
                station_to_play = config['bookmark_A'] if event.code == 'BTN_TRIGGER' else config['bookmark_B']
                if station_to_play is None or station_to_play not in radio_stations:
                    current_station_index = 0
                    start_stream(stations[current_station_index])
                else:
                    start_stream(station_to_play)
                    current_station_index = stations.index(station_to_play)
            last_event_time[event.code] = current_time
            select_pressed_time = 0
        elif event.code == 'BTN_BASE4':
            if current_process is None:
                start_stream(stations[current_station_index])
            else:
                stop_stream()
            last_event_time['BTN_BASE4'] = current_time

    elif event.ev_type == 'Absolute':
        if event.code == 'ABS_X' and current_time - last_event_time['ABS_X'] > DEBOUNCE_TIME:
            if event.state < 100:
                current_station_index = (current_station_index - 1) % len(stations)
                start_stream(stations[current_station_index])
            elif event.state > 150:
                current_station_index = (current_station_index + 1) % len(stations)
                start_stream(stations[current_station_index])
            last_event_time['ABS_X'] = current_time

        elif event.code == 'ABS_Y' and current_time - last_event_time['ABS_Y'] > DEBOUNCE_TIME:
            if event.state < 100:
                adjust_volume("up")
            elif event.state > 150:
                adjust_volume("down")
            last_event_time['ABS_Y'] = current_time

config = load_config()
start_stream(config.get('bookmark_A', stations[0]))

while True:
    events = get_gamepad()
    for event in events:
        process_event(event)
