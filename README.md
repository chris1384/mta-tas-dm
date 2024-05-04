<a href='https://lua.org' target="_blank"><img alt='lua' src='https://img.shields.io/badge/mom_i made it in lua-100000?style=plastic&logo=lua&logoColor=white&labelColor=5C5C5C&color=5E56FF'/></a>
<a href='https://buymeacoffee.com/chris1384' target="_blank"><img alt='Buy me a Coffee!' src='https://img.shields.io/badge/Buy%20Me%20A%20Coffee!-FF8000'/></a>
### NOTE: THIS RESOURCE IS NOT INTENDED FOR CHEATING! ANY REQUEST REGARDING TAS IMPLEMENTATION ON OTHER SERVERS/PROVIDING SERVER VULNERABILITIES IS NOT TOLERATED AND WILL BE IGNORED!

## Recording & Seamless Segmenting Run Tool v1.4 for MTA:SA
### by chris1384 @2020

This is a resource intended for creating segmented runs for (hard) deathmatch racing maps. Should only be used for demonstrational purposes.

Back in 2020, I've worked on a script that undos the whole run you've made if you did a mistake. I've always been dreaming about getting TAS scripts working with MTA:SA, but due to RenderWare random movement and calculations, the only way to make this sort of tool was to record every frame in real time, which manually adding inputs to a file was impossible.

It is a complete remake over the old one. It might have a better overall performance, but that depends on the users gear.

## Here's a list of what the tool is capable of:
- recording the whole run, having full information about every frame ran.
- playbacking the run recorded before
- using warps to get over any mistake in the run
- real-time rewinding similar to Training rooms in Multigamemode servers
- Frame-By-Frame recording, which locks your position and manually set next and previous frames
- switching to regular and frame-by-frame recording anytime you want
- continuing the run starting from the end and seeking the position based on a frame number
- automatically starting recording or playbacking on map start (Auto-TAS)
- debugging the run and showing a lot of info about what you're doing
- saving and loading records on client or serverside (suggested by *SKooD*)
- slowmotion recording for more precise inputs (1.4*)

## Tutorial
### 1. Downloading (for dummies)
- Press the green button that shows Code.
- Select 'Download ZIP'.

### 1.1 Installation
***You must have a working MTA:SA server and existing resources folder.***
- Locate your MTA:SA main folder,
- Travel to mta:sa/server/mods/deathmatch,
- Choose one of the versions of TAS to install ('new' is recommended)
- Paste *tas* folder in the resources folder,
- Open your server or type *refresh* in the server console if it's already running,
- Type *start tas* in the server console,
- You should see an output about the resource that got started.

- Done!

### 1.2 Configuration and file briefing
***- client.lua***
- *client.lua* file contains everything that makes TAS running.
- Open it using Notepad or your preferred IDE (recommended/Notepad++) to see helpful notes inside.
- CVARs can be modified directly from the file itself without changing them manually using /tascvar (see tas.settings array for info)

***- server.lua***
- *server.lua* is used for events regarding model changes and race events (used in Auto-TAS).
- Added file saving and downloading handlers between clients and the server.

- That's it

### 2. Commands
***You can also experiment with the resource on a freeroam gamemode, just to get the feel of it.***
- When the tool is loaded, you should see a welcoming message of it.
- Typing /tashelp will show you a list of commands:
```
/record - start regular, real-time recording
/playback - start playbacking the run you've recorded
/rsw - save warp
/rlw [ID] - load warp
/rdw - delete latest warp
1.3* /recordf - start frame-by-frame recording
1.3* /switchr - switch between regular and frame-by-frame recording
1.3* /nf [frames] - set next frame while frame-by-frame recording
1.3* /pf - delete the latest frame while frame-by-frame recording
/resume [frame number] - continue the recording (from a frame number)
/seek [frame number] - seek to a frame while playbacking
BACKSPACE - hold it to rewind the run while recording (+Left Shift to speed it up | +Left Alt to slow it down)
/saver [name] - save the recorded data to a file
/loadr [name] - load an existing run
1.4* /saverg [name] - save the recorded data to a file on server
1.4* /loadrg [name] - download a .TAS file from the server (use with /loadr upon finishing)
/autotas - toggle Auto-TAS (trigger record or playback on map start)
/clearall - clear all data
1.4* /forcecancel - stops any data from being sent or gathered from the server
/debugr [level] - toggle debugging
1.4* /tascvar [key] [value] - change settings in-game (use '/tascvar show' to see all commands)
```

### 3. Using the tool (example)
- Get in a vehicle to begin
- Write */record* to start recording your run.
- Drive around the map, use the warp commands to get back in time, make it the perfect driving experience.
- If everything looks good, type */record* again to finish it.
- Now type */playback* to see your magnificent run.
- Well done!

### 4. Additional Info (FAQ)
***What's TAS anyway?***
- TAS is short for *Tool Assisted Speedrun*. Basically, you play the game using special tools to construct your run so that it would get to its goal in the fastest time possible.
- Although its main use is to have the fastest route, it can also be used to record maps that are difficult to do in one segment.

***Is it really TAS?***
- Yes and no.
- This is not an external software. It's a simple LUA script that can be used on local servers in order for players to achieve some goals that couldn't be able to do before.
- Since GTA:SA depends entirely on random movement. It's impossible to map the keys for every frame and expect to run it the same every time. These actions are not as deterministic as they are in Trackmania.
- So in order to achieve a perfect playback, position and rotation of the vehicle are also used to manage these perfect runs. You can test the randomness by disabling helper functions and playback your run using only keys: ***/tascvar useOnlyBinds true***
  
***Differences between TAS and other Recording scripts***
- Almost every recording script that has been made in the past are meant to be used exclusively on the Map Editor.
- While in it's core is yet an another recording script, this one has save & load warps directly implemented into it, for creating segmented runs and other features so you can create your seamless run for different purposes.
- TAS focuses on recording every player action in order to display everything perfectly on every frame, and having it played back whenever you want. It can be used everywhere while your ped is in a vehicle.
- It also includes features that tries to fix any imperfections on the go so it shouldn't be glitchy most of the time.

***Can you run TAS on public servers?***
- TAS is like any other tool that has been made for MTA:SA, so yes, as long as you have the permissions to upload and start resources.

***Where are my saved runs?***
- .TAS files are saved as private data, these are stored in *MTA San Andreas/mods/deathmatch/priv*
- Search for the resource name and you'll be able to find the resource, along with the saved runs folder.
- This option can be changed in version 1.4 using the following command: ***/tascvar usePrivateFolder false***

## Something you would want implemented or got any bugs? Fill out a form in the Issues section!
## For any additional help, please contact me on Discord: *chrisu#9616* (or just chris1384) or on MTA:SA forums (chris1384).
