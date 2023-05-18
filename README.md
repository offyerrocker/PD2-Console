# Console

Adds an interactive Lua shell in-game.

Its main purpose is to allow you to enter and execute direct Lua code, or premade console commands.
This mod should not be conflated or confused with any official developer console.
This is merely a tool for developing mods using Lua.

Although all code and commands run from this command prompt are encapsulated in a pcall ("protected call") to prevent crashes from syntax errors or other compilation problems, this is not a 100% foolproof method for protecting you from errors. pcall can only prevent crashes on the Lua side; errors in native calls (eg. Application/Diesel C functions exposed to Lua) called through the Console may still crash.

Commands may not be mixed with other commands or with user-input Lua code by default. 

Requires SuperBLT and BeardLib. Install into the mods folder. The keybind to toggle the shell is not bound by default and must be set in the Mod Keybinds menu, or in the Mod Options menu under "Command Console Options".
