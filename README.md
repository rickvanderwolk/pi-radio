# Pi radio

![Pi-radio](IMG_0492.png)

A Python (Raspberry Pi) script to control online radio streaming with a gamepad. Switch between stations, adjust volume, and manage playback using gamepad buttons.

## Hardware

- Raspberry Pi; I use a Pi 4 but any Pi will probably do just fine. Just keep in mind that some models don't have a mini jack (including Pi 5) and normal USB ports. 
- PC speakers; I use cheap PC speakers with a mini jack for audio and USB for power (https://www.bol.com/nl/nl/p/compacte-stereo-luidsprekers-audiocore-ac870-pc-speakers/9200000099727061/) but you can use whatever you like.
- Gamepad; I use a NES style USB gamepad. Something like https://www.amazon.com/Controller-suily-Joystick-RetroPie-Emulators/dp/B07M7SYX11 (They don't have them anymore where I bought them). But any gamepad will do. You might need to change the event types and event codes in `process_event` though.
- Power supply for the Pi
- Power supply for the PC speakers; I recommend using a separate power supply for the PC speakers, as I noticed powering them through one of the USB ports on the Pi resulted in more audio stuttering
- Optional: Case for the Pi; I've used https://www.thingiverse.com/thing:3975417 but you can use any case you want
