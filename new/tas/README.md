# Version 1.4

This is an on-going preview of TAS, which includes flawless track recording and playbacking no matter the FPS you're using. Contains optimized scripts so it should not cause you any FPS issues.

It has all of the basics you'll ever need with some extra features that the old version is lacking. Missing function is: Frame-by-Frame recording.

Uses custom file format, files generated by version 1.3 or lower are deprecated and won't work upon loading with the new one. Loading a huge .tas file might screw up your game (infinite loop, memory fill or similar). It needs an async function.

Open `client.lua` for settings and helpful info.
Also check out `server.lua` to configure your serverside saving of .TAS files.

I decided to make a revamp of it, recommended to use this one because the older version can produce weird spacing between frames.
