# use `bash start_radio.sh` to start instead of calling this script directly

import time
import os
import signal
import subprocess
from inputs import get_gamepad

DEBOUNCE_TIME = 0.2

last_event_time = {
    'BTN_BASE3': 0,
    'BTN_BASE4': 0,
    'BTN_TRIGGER': 0,
    'BTN_THUMB': 0,
    'ABS_X': 0,
    'ABS_Y': 0
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
    'slam_nonstop': 'https://stream.slam.nl/web10_mp3',
    'cadena_digital': 'http://185.23.192.118:8006/;stream.mp3',
    'dnbradio': 'https://azrelay.drmnbss.org/listen/dnbradio/radio.mp3',
}

stations = list(radio_stations.keys())
current_station_index = 0
current_process = None

def start_stream(station):
    global current_process
    stop_stream()
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
    global current_station_index
    current_time = time.time()

    if event.ev_type == 'Key':
        if event.code == 'BTN_BASE3' and event.state == 1 and current_time - last_event_time['BTN_BASE3'] > DEBOUNCE_TIME:
            stop_stream()
            last_event_time['BTN_BASE3'] = current_time
        elif event.code == 'BTN_BASE4' and event.state == 1 and current_time - last_event_time['BTN_BASE4'] > DEBOUNCE_TIME:
            start_stream(stations[current_station_index])
            last_event_time['BTN_BASE4'] = current_time
        elif event.code == 'BTN_TRIGGER' and event.state == 1 and current_time - last_event_time['BTN_TRIGGER'] > DEBOUNCE_TIME:
            current_station_index = 0
            start_stream(stations[current_station_index])
            last_event_time['BTN_TRIGGER'] = current_time
        elif event.code == 'BTN_THUMB' and event.state == 1 and current_time - last_event_time['BTN_THUMB'] > DEBOUNCE_TIME:
            last_event_time['BTN_THUMB'] = current_time

    if event.ev_type == 'Absolute':
        if event.code == 'ABS_X':
            if event.state < 128 and current_time - last_event_time['ABS_X'] > DEBOUNCE_TIME:
                current_station_index = (current_station_index - 1) % len(stations)
                start_stream(stations[current_station_index])
                last_event_time['ABS_X'] = current_time
            elif event.state > 128 and current_time - last_event_time['ABS_X'] > DEBOUNCE_TIME:
                current_station_index = (current_station_index + 1) % len(stations)
                start_stream(stations[current_station_index])
                last_event_time['ABS_X'] = current_time
        elif event.code == 'ABS_Y':
            if event.state < 128 and current_time - last_event_time['ABS_Y'] > DEBOUNCE_TIME:
                adjust_volume("up")
                last_event_time['ABS_Y'] = current_time
            elif event.state > 128 and current_time - last_event_time['ABS_Y'] > DEBOUNCE_TIME:
                adjust_volume("down")
                last_event_time['ABS_Y'] = current_time

start_stream(stations[current_station_index])

while True:
    events = get_gamepad()
    for event in events:
        process_event(event)
