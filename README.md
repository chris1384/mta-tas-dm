<a href='https://lua.org' target="_blank"><img alt='lua' src='https://img.shields.io/badge/mom_i made it in lua-100000?style=plastic&logo=lua&logoColor=white&labelColor=5C5C5C&color=5E56FF'/></a>

## Recording & Seamless Segmenting Run Tool for MTA:SA
### by chris1384 @2020

This is a resource intended for creating segmented runs for (hard) deathmatch racing maps. Should only be used for demonstration purposes.
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
- * automatically starting recording or playbacking on map start
- debugging the run and showing a lot of info about what you're doing
- saving and loading records

## Tutorial
### 1. Installation
***You must have a working MTA:SA server and existing resources folder.***
- Locate your MTA:SA main folder,
- Travel to mta:sa/server/mods/deathmatch,
- Paste *mta-tas-dm* folder in the resources folder,
- Open your server or type *refresh* in the server console if it's already running,
- Type *start mta-tas-dm* in the server console,
- You should see an output about the resource that got started.

- Done!

### 2. Commands
***You can also experiment with the resource on a freeroam gamemode, just to get the feel of it.***
- When the tool is loaded, you should see a welcoming message of it.
- Typing /tashelp will show you a list of commands:
```
/record - start regular, real-time recording
/recordf - start frame-by-frame recording
/playback - start playbacking the run you've recorded
/switchr - switch between regular and frame-by-frame recording
/rsw - save warp
/rlw - load latest warp
/rdw - delete latest warp
/nf [frames] - set next frame while frame-by-frame recording
/pf - delete the latest frame while frame-by-frame recording
/resume [frame number] - continue the recording (from a frame number)
/seek [frame number] - seek to a frame while playbacking
BACKSPACE - hold it to rewind the run while recording (+Left Shift to speed it up | +Left Alt to slow it down)
/saver [name] - save the recorded data to a file
/loadr [name] - load an existing run
* /autotas - toggle Auto-TAS (trigger record or playback on map start)
* /clearall - clear all data
/debugr - toggle debugging
```

### 3. Using the tool (example)
- Get in a vehicle to begin
- Write */record* to start recording your run.
- Drive around the map, use the warp commands to get back in time, make it the perfect driving experience.
- If everything looks good, type */record* again to finish it.
- Now type */playback* to see your magnificent run.
- Well done!

### 4. Additional Info (FAQ)
***Where are my saved runs?***
- Your runs are stored in mta:sa/mods/deathmatch/priv
- Search for the resource name and you'll be able to find the resource, along with the saved runs folder.

***Why is the NOS always running out? Shouldn't I get full nitrous when loading a warp?***
- This is not how it's supposed to work. Depending on the map, nitrous pickups might not be available everytime so you should play it without that benefit.
Doing this change might give you an unfair advantage and possibly look strange while playbacking, because you will be getting speed (or full NOS level) from nothing.

***Why is the tool lagging so much? Will be there any optimization in the future?***
- Again, this depends on the users PC specs and what the user or PC is doing at that time. Having a lot of apps in the background may cause frame drops or general performance issues, this in fact could ruin your recording or preview of the run, making it look choppy or even slowing it down.
- Optimization is also one of my main missions while developing this tool. I'm currently trying to figure out which parts of the code can be optimized without losing any of the features it contains.
- I've also tested this tool using a low-end laptop I had at my disposal, everything was working smoothly and didn't had any problems with it. If you still get any issues with it, please seek out some ways online on how to clean your PC or even upgrade it.

## Upcoming features
- Checkpoints, so you can see where you gain or lose time. You must complete the map from start to finish so you can compare it afterwards. (idea by Geass)
- Slowmotion
- Pause recording on FPS drops
- Adding more info (warp data, checkpoints data, frame-by-frame debug lines etc.) into the save files
- Maybe some ghost peds/vehicles

## For any help, please contact me on Discord: *chrisu#9616* or on MTA:SA forums (chris1384).
