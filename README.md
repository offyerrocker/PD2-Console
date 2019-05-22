# PD2-Console
Command Prompt Console mod for PAYDAY 2

"Command Console" adds a toggle-able command prompt UI in-game.
This command prompt can be used to enter and execute direct Lua code, or premade console commands.
This mod should not be conflated or confused with any official developer console. This will not allow you to see debug logs or debug UIs by PAYDAY 2's developers (at least, not by default.) 
This is merely a tool for developing mods using Lua.

Although all code and commands run from this command prompt are encapsulated in a pcall ("protected call") to prevent crashes from syntax errors or other compilation problems, there is no access protection for illegal actions or code that may adversely affect your game's function outside of this pcall.
For example, running 

`return 1 / 0` 

will not crash, and will instead log an error "div 0 error" to the console.
However, any successful code execution may still cause crashes in any affected code outside of the console, e.g. replacing a value that the game uses with a nil or invalid value. 
This code will only execute on your client; remote code execution is a security exploit, not a planned feature.
Commands may not be mixed with other commands or with user-input Lua code by default. 


