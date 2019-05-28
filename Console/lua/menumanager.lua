--[[ TODO: FEATURES BEFORE PUBLIC 1.0

- Add basic debug commands:
	- log [msg] [name]: outputs to blt log; otherwise identical to _log()
	- t_log/PrintTable [table] [optional: name] [optional: tier]: prints nicely-formatted table to console

Console:
	* Parse spaces in quotes (strings) in command line (requires string.split alternative)
	* Formatted timestamp in Console 
		* Options: Game time or system time
	
Command "/bind":
	* use /bindid for using existing blt keybinds;
	* use /bind for individual keyboard/mouse inputs by name
	* blacklist ids of subcommands like:
		* help
		* list
	* Separate subtables for self._custom_keybinds
		* keybindid 
		* keyname

Command "/teleport":
	* optional 3 args for rotlook

Persist Scripts:
	* Option to add by command, as with "/tracker track"

Add optional HUD waypoint to position tagging, a la Goonmod Waypoints

Tracker:
	add var/cmd to recall value of tracked items for use in cmds

	make tracker more intuitive

Scroll Bar: 
	- Fix the goddamn scroll bar
		-update on any scroll action (scrollwheel, pgup, pgdn, new log)
		- scroll blocks should render over scroll bar
		- scroll bar should move properly
		- scroll bad should be inside a frame so as not to render over other things
		
		- Scroll bar at top: earliest logs
		- Scroll bar at bottom: latest logs
		
		- Scroll height: (frame_h - history_h)
			- decreases after history_h > frame_h, down to [min] at history_h == frame_h * [10] 
		

		if history_h <= frame_h then 
			scroll_h = frame_h
		else
			scroll_h = history_h / (frame_h * 10)
		end
		
		- scroll_h = frame_h / history_h

Navigation
	- CTRL + (LEFTARROW/RIGHTARROW) to move cursor to next space/special char in left/right direction (spaces? periods? commas? todo figure that out)


Settings
	- "Reset settings" button
	- Console window mover in mod options
	- Optionally, allow overriding log() function
		- Add console command "enablelogs" to enable/disable BLT logs or something


Debug HUD
	- wrap Debug HUD unit info in nice safe pcall() (whichever isn't already)
	- add more unit info 
	- add unit info keybind to hide interface
	- add unit info /shortcommands to display info (accessible through chat)

- Enable Console in main menu (init console window somewhere other than where it is in hudmanager)
			
- Import chat commands from OffyLib + allow chat in Offline Mode (disabled by default)
	
- fix application:close crashing instead of quitting
	...Application:quit()?
	
Keybinds functions:
	* Hold [modifier key] to select enemy and freeze AI
	- Select deployable at fwd_ray
	- Select misc object at fwd_ray




---extra features, for post release

Command Help
	- Add remaining syntax + usage + /help
	- Add command tooltips
	- update self.command_list to have command_string as well as short, single-line description
		eg
		self.command_string = {
			"teleport" = {
				func = [func],
				cmd = "Console:cmd_teleport($ARGS)",
				desc = "Hewwo??"
			}
		}
		

- re-absorb upd_caret to update_scroll for var efficiency

- Instead of adding vspace by value, check against previous log's xy/wh values and add to those (also solves v whitespace issue)
	- Add remaining passed params to new_log_line()
	- Fix new_log_line() text height calculation (string.match count for "\n"?)
	- Move cmd history properly when sending new commands

- Scan for \n in strings, and replace with separate Log() line
	- Overflow to newline for character limits (should check against max length setting)
		- \n works for standard strings and hud text panels


- Reset movement when opening console (so that positive input is not "stuck" if opening console while applying input)
	
- Fix [I stopped typing here because I got distracted and never finished the thought. I guess I'll never know what it is that needed to be fixed]

- Localize the whole damn thing
	- Add macros to support other languages rather than using a million string fragments
	- Find people willing to help

- Revert to earlier version to return data automatically (include optional new, alternate behavior?)
	- callback tests confirmed pcall() and loadstring() functioning as expected

- Add console settings as cl_blanketyblank

- Standardize margins + values in hudmanagerpd2
- Fancy fadeout/fadein for command window
- Fancy texture(s) for command window
- Add better highlight visibility
- Add special character actions:
	- Re-enable tilde (`/~) as inputs:
		* Fix tilde entering on close console (or at all) if also bound to console
			* Add or switch key (alt?) to enable entering this key
			
		* Recommend that one mod that re-adds characters to the font, such as "~"
	- CAPSLOCK support?
	- SHIFT+RETURN for newline? (invisible to code, only for organization)
	- ALT-code support?

- Add SECRET SECRETS

- Implement GetConsoleAddOns hook for third-party command modules /persist callback scripts etc

-----------------
changes from last version:

* Fixed new character insertion (typing as usual) in the wrong spot after having moved the selection caret 
* Console now saves the last change you made before browsing command history; this can be recovered by using the arrow keys (DOWN/UP) to navigate toward the most recent command
* Fixed "/restart cancel" cancelling the timer but then restarting immediately anyway
* Fixed refreshing the restart timer with subsequent "/restart [timer]" commands not displaying the time 
* Added /teleport (aka /tp). Takes three arguments: x, y, and z. Leave blank or use argument1 "tag" to teleport to tagged_position.
* Added unit selection feature
	* Activated by keybind or command
	* Selecting a unit is now referred to as "tagging" a unit
	* Tagging a unit will automatically show the unit's hitbox and navigation path, as well as other stats (name, hp, weapon)
		* The ability to change what displays will be added in the future
	* This unit may be used for reference in commands that involve unit manipulation
* Added position selection feature
	* Activated by keybind or command
	* Selecting a position is now referred to as "tagging" a position
	* Tagging a position will automatically render a debug shape at the location
	* This position may be used for reference in commands that involve unit manipulation, including teleporting oneself
* Added "/tracker track [id] [variable]", which automatically adds a hud element with name [id] and refreshes the displayed value of [variable] every frame to that hud element
* Added Console:c_log() to output to chat. Theoretically should be able to handle any number of arguments, but does not adjust for the character limit
* Probable fix for Application:quit()/close() crashing rather than closing
--]]


_G.Console = {}

Console.settings = {
	font_size = 12,
	margin = 2,
	scroll_speed = 12, --pixels per scroll action
	scroll_page_speed = 720, --pixels per page scroll action
	esc_behavior = 1,
	auto_evaluate = true
}

Console.path = ModPath
Console.loc_path = Console.path .. "localization/"
Console.save_name = "command_prompt_settings.txt"
Console.save_path = SavePath .. Console.save_name
Console.options_name = "options.txt"
Console.options_path = Console.path .. "menu/" .. Console.options_name
Console.keybinds_name = "command_prompt_keybinds.txt" --custom keybinds; separate from BLT/mod keybinds
Console.keybinds_path = Console.save_path .. Console.keybinds_name
Console._focus = false --whether or not console is visible/interactable
Console.caret_blink_interval = 0.5 --duration in seconds of cursor flashes
Console._caret_blink_t = 0 --last t for caret blink (calculations)
Console.selection_dir = 1 --direction to select in using SHIFT + [LEFT/RIGHT]ARROW
Console.input_interval_initial = 0.5 --first repeat interval between inputs, to prevent accidental inputs
Console.input_interval = 0.05 --repeat interval for holding a key (applied after initial input_interval)
Console.input_interval_done = false --flag for enabling input_interval_initial
Console._typing_callback = 0 --lol idk
Console._skip_first = false --used to ensure that console-management buttons (like the "enter" or "`" the console open key) don't trigger as text inputs
Console.num_lines = 1 --updated count of number of text lines in the console
Console.num_commands = 1
Console.selected_history = false --currently displayed command history for when browsing command history with (UP/DOWN)ARROW
Console.input_t = 0 --last t of valid character/text input
--Console._panel = panel
Console._enter_text_set = true --i'm... not totally sure what that does
--Console._delayed_result = false --stores the result of pcalled Log(), so that it can be displayed in order; unused
Console._adventure = false --WHAT TIME IS IT
Console.selected_unit = false --used for unit manipulation 
Console._restart_timer = false --used for /restart [timer] command: tracks next _restart_timer value to output (every second)
Console._restart_timer_t = false  --used for /restart [timer] command: tracks time left til 0 (restart)
Console._dt = 0 --should never be directly used for anything except calculation of dt itself
Console.selected_tracker = nil --string; holds id index of currently selected tracker from table _persist_trackers, NOT the element
Console.tagged_unit = nil --used for selected_unit for unit manipulation
Console.tagged_position = nil --used for waypoint/position manipulation
Console._failsafe = false --used for logall() debug function; probably should not be touched
--todo slap these in an init() function and call it at start


Console.command_history = {
--	[1] = { name = "/say thing", func = (function value) } --as an example
}

Console.color_data = { --for ui stuff
	scroll_handle = Color(0.1,0.3,0.7),
	chat_color = Color("8650AC"),
	debug_brush_tagged_enemy = Color.yellow:with_alpha(0.1),
	debug_brush_enemies = Color.red:with_alpha(0.1),
	debug_brush_world = Color.green:with_alpha(0.1)
}

Console.quality_colors = {
	normal = Color("B2B2B2"), --grey
	unique = Color("FFD700"), --yellow 
	vintage = Color("476291"), --desat navy ish
	genuine = Color("4D6455"), --desat forest green ish
	strange = Color("CF6A32"), --desat orangey
	unusual = Color("8650AC"), --purple
	haunted = Color("38F3AB"), --turquoise
	collector = Color("AA0000"), --collector's, but i hate dealing with release + quotes in strings. dark red
	decorated = Color("FAFAFA"), --lighter grey?
	community = Color("70B04A"), --also self-made; magenta
	valve = Color("A50F79"), --burgundy?
	void = Color("544071"), --purple; more sat than unusual
	solar = Color("E1834F"), --orange
	arc = Color("6F8EA2"), --powder blue
	common = Color("43734B"), --moderately green
	rare = Color("547C96"), --blue; lighter than vintage
	legendary = Color("522F65"), --purple; lighter than unusual
	exotic = Color("CEAE33") --(bright lemony yellow)
}

Console._tagunit_brush = Draw:brush(Console.color_data.debug_brush_enemies) --arg2 is lifetime
Console._tagworld_brush = Draw:brush(Console.color_data.debug_brush_world)


Console.command_list = { --in string form so that they can be called with loadstring() and run safely in a pcall; --todo update
	help = "Console:cmd_help($ARGS)", --list all commands
	about = "Console:cmd_about()", --output basic mod info about Console
	contact = "Console:cmd_contact()", --output mod author's contact info
	info = "Console:cmd_info($ARGS)", --not implemented
	say = "Console:cmd_say($ARGS)", --outputs message to chat as one would chat normally
	whisper = "Console:cmd_whisper($ARGS)", --outputs private message to user
	tracker = "Console:cmd_tracker($ARGS)", --various commands related to tracking variables and displaying their contents to the HUD
	god = "OffyLib:EnableInvuln($ARGS)", --sorry kids you don't get the kool cheats unless you're me
	exec = "Console:cmd_dofile($ARGS)", --dofile. literally just dofile.
	["dofile"] = "Console:cmd_dofile($ARGS)", --sorry, just dofile again. and don't you give me your syntax-highlighting sass, np++, i know dofile is already a thing
	teleport = "Console:cmd_teleport($ARGS)",
	tp = "Console:cmd_teleport($ARGS)",
	bind = "Console:cmd_bind($ARGS)", --is this tf2.jpg
	bindid = "Console:cmd_bindid($ARGS)",
	unbind = "Console:cmd_unbind($ARGS)", --i hear unbindall in console gives you infinite ammo :^)
	time = "Console:cmd_time()", --i don't know when this would be useful
	date = "Console:cmd_date()", --outputs system date + time to console (preformatted)
	quit = "Console:cmd_quit($ARGS)", --closes payday 2 executable (after confirm prompt)
	restart = "Console:cmd_restart($ARGS)", --restarts heist day; argument is seconds delay to restart
--	fov = "Console:cmd_fov($ARGS)", -- borked atm
--	ping = "Console:cmd_ping($ARGS)", --not implemented
	savetable = "Console:cmd_writetodisk($ARGS)", -- [data] [pathname]
--	adventure = "Console:cmd_adventure($ARGS)",
	stop = "Console:cmd_stop($ARGS)" --for stopping persist scripts or if logall() has gone awry
}

Console.h_margin = 24
Console.v_margin = 3

Console._keybind_cache = { --whether the key is currently being held (or was last frame)
--	[keybind_id_1] = true,
--	[keybind_Id_2] = false
}
Console._custom_keybinds = {
	--[[
	[keybind_id] = {
		clbk = callback(Class,SelfArg,"functionname",'additional_arguments'), --function to run
		persist = true --if true, run every frame; else, run only on pressed (once per press)
	}
	--]]
}

Console._persist_scripts = { --any scripts in this table will run every frame (as they are persist scripts) until they are removed. see documentation/help for how to use this.	
--[[
	[persist_script_id] = {
		clbk = callback(classname, classname_2, "functionname", additional_arguments),
		clbk_fail = callback(classname, classname_2, "functionname", additional_arguments), --called if clbk fails to execute
		clbk_success = callback(classname, classname_2, "functionname", additional_arguments), --called if clbk returns true (MUST return true (or non/false or non-nil value), not simply execute successfully)
		log_fail = true, --if true, log errors
		log_success = true, --if true, log successful runs
		log_all = true --if true, logs on the status of this persist script or its fail/success callbacks. equivalent to having both (log_fail = true) and (log_success = true)
		
	}	
--]]
}

Console._persist_trackers = { --storage for HUD elements; todo rename
	
}


function Console:OnInternalLoad() --called on event PlayerManager:_internal_load()
	--load keybinds
	--do stuff for Console development here such as creating tracker elements
	self:SetupHitboxes()
end

function _G.Log(...)
	Console:Log(...)
end

function Console:Log(info,params)
--	local color = params and params.color or Color.white
--	local margin = params and params.h_margin
	if not info then
--		return --todo setting to disable logging if nil value? optional parameter?
	end
	
	local line = self.num_lines
	local new_line = self:new_log_line(params)
	if new_line and alive(new_line) then 
		new_line:set_text(tostring(info))
	end
end

function Console:new_log_line(params)
	params = params or {}
	local font_size = self:GetFontSize()
	local color = params.color or Color.white:with_alpha(1)
	local v_div = params.new_cmd and font_size or 0

	local panel = self._panel
	local frame = panel:child("command_history_frame")
	local history = frame:child("command_history_panel")
	local line
	local v_margin = self.v_margin
	local h_margin = params.h_margin or self.h_margin
	history:set_h(history:h() + font_size + v_margin)
	local new_x = h_margin
	local new_y = (2 + self.num_lines) * font_size
	if not history:child("history_cmd_" .. tostring(self.num_lines)) then 
		local previous_line = history:child("history_cmd_" .. tostring(self.num_lines - 1))
		if previous_line and alive(previous_line) then
		--todo for every instance of \n in previous_line do y = y + v_margin + font_size
	--[[
			local x,y,w,h = previous_line:text_rect()
			KineticHUD:_debug(x,1)
			KineticHUD:_debug(y,2)
			KineticHUD:_debug(w,3)
			KineticHUD:_debug(h,4)
--OffyLib:c_log(y,"y")
--			new_y = new_y + v_div
			--can't use Log() here cause it'll overflow from infinite recursive errors.
			--how ironic, it could save others from crashing, but not itself
			KineticHUD:_debug(v_margin,5)
			KineticHUD:_debug(previous_line:bottom(),6)
	--]]
--			new_y = y + v_div
		end
		line = history:text({
			name = "history_cmd_" .. tostring(self.num_lines),
			layer = 1,
			x = new_x, --margin
			y = new_y,
--			w = 100,
			h = font_size * 1.15,
			text = "[" .. tostring(self.num_lines) .. "] loading...",
			font = tweak_data.hud.medium_font,
			font_size = font_size,
			color = color
		})
	else
		log("Console: ERROR! history line " .. tostring(self.num_lines) .. " already exists!")
	end
	self:refresh_scroll_handle()
	self.num_lines = self.num_lines + 1
	return line
end

function Console:c_log(...)
	local arg = {...}
	local message
	for _,v in ipairs(arg) do
		message = message and (message .. " : " .. tostring(v)) or tostring(v)
	end
	
	local col = self.color_data.chat_color
	if not message then -- if message == "" then 
		message = "(EMPTY LOG)"
		col = self.quality_colors.collector
	end
	managers.chat:_receive_message(1,"[CONSOLE]",message,col)
	self:Log(message,{color = col})
end

function Console:cmd_tracker(subcmd,id,...) --interpret
	subcmd = tostring(subcmd)
	--todo get success from directed function; display error message if invalid tracker/syntax
	if subcmd then 
		local i = 0
		if subcmd == "setxy" then 
			self:SetTrackerXY(id,...)
		elseif subcmd == "list" then 
			self:Log("Debug HUD Trackers:")
			for tracker_id,element in pairs(self._persist_trackers) do 
				i = i + 1
				self:Log(i .. ": [" .. tracker_id .. "] | Text: [" .. tostring(element:text()) .."]")
			end
			--list all trackers by number
		elseif (subcmd == "setcolor") or (subcmd == "color") then
			self:SetTrackerColorRGB(id,...)
			--todo function should interpret color input type
		elseif (subcmd == "add") or (subcmd == "new") or (subcmd == "create") then
			self:CreateTracker(id)
		elseif subcmd == "set" then 
--			self:SetTrackerData(id,...)
			self:SetTrackerValue(id,...)
		elseif subcmd == "remove" or subcmd == "delete" then 
			self:RemoveTracker(id)
		elseif subcmd == "track" then 
			self:RegisterTrackerUpdater(id,...)
		elseif subcmd == "help" then
			self:Log("Syntax: /tracker [string: subcommand] [string: id] [value]",{color = Color.yellow})
			self:Log("Subcommands: color, add/create/new, help, list, remove/delete, select, setxy",{color = Color.yellow})
			self:Log("Usage: Creates display values on the HUD for you to see. Useful for tracking values that change frequently and would flood a normal console.",{color = Color.yellow})
		elseif subcmd == "select" then --select by number in case it is not feasible to write tracker's string id name
			for tracker_id,element in pairs(self._persist_trackers) do 
				i = i + 1
				if i == tonumber(id or -1) then 
					self.selected_tracker = tracker_id
				end
			end
		end
	end
end

function Console:CreateTracker(id)
	local tracker = self:GetTrackerElementByName(id)
	if tracker then 
--		self:Log("Error: CreateTracker(" .. tostring(id) .. ") Tracker" .. tostring(id) .. "Already exists!",{color = Color.red})
		return tracker
	end
	tracker = self._debug_hud:text({
		name = tostring(id),
		text = tostring(id) .. ": [empty tracker]",
		layer = 1,
		x = 500,
		y = 100,
		font = tweak_data.hud.medium_font,
		font_size = self:GetFontSize(),
		color = Color.white
	})
	self._persist_trackers[tostring(id)] = tracker
--	self:SetTrackerData(id,data)
	return tracker
end

function Console:GetTrackerElementByName(id)
	if id ~= nil then 
		return self._persist_trackers[tostring(id)]
	end
end

function Console:RegisterTrackerUpdater(id,var)
	local cmd_str = "Console:SetTrackerValue('" .. tostring(id) .. "'," .. tostring(var) .. ")"
	local func,error_message = loadstring(cmd_str)
	
	if func and not error_message then 
		self:CreateTracker(id)
		self:RegisterPersistScript("Tracker_" .. tostring(id),func)
		self:Log("done " .. cmd_str,{color = Color.green})
		Console._last_func_ran = func
	else
		self:Log("ERROR: RegisterTrackerUpdater(" .. tostring(id) .. "," .. tostring(var) .. ") failed with error:",{color = Color.red})
		self:Log(tostring(error_message),{color = Color.red})
	end
end

--set data for the tracker hud element: 
function Console:SetTrackerData(id,data) --should be called on create or by internal functions; short /commands should only set one parameter at a time
	if not (data and type(data) == "table") then 
		self:Log("ERROR: Bad data to SetTrackerData(" .. tostring(id) .. ",[non-table value]")
		return 
	end
	local tracker = self:GetTrackerElementByName(id)
	if tracker and alive(tracker) then 

		local text = data.text or "No data"
		local layer = data.layer or 90
		local x = data.x or 10
		local y = data.y or 10
		local font = data.font or tweak_data.hud.medium_font
		local font_size = data.font_size or self:GetFontSize()
		local color = data.color or Color.white
		tracker:set_text(text)
		tracker:set_layer(layer)
		tracker:set_x(x)
		tracker:set_y(y)
		tracker:set_font(font)
		tracker:set_font_size(font_size)
		tracker:set_color(color)
		--all that good stuff
	end
end

function Console:SetTrackerValue(id,value) --setting text value only; should be used for updates, and linked to short command
	if id == "selected" then 
		id = self.selected_tracker
	end
	local tracker = self:GetTrackerElementByName(id)
	if tracker and alive(tracker) then 
		tracker:set_text(value)
	end
	return tracker
end

function Console:SetTrackerColor(id,col) --not used
	local tracker = self:GetTrackerElementByName(id)
	if tracker and col then --type(col) == "userdata color"
		tracker:set_color(col)
	end
end

function Console:SetTrackerColorRGB(id,r,g,b,a) --technically, r/g/b/a are all optional arguments
	if id == "selected" then 
		id = self.selected_tracker
	end
	local tracker = self:GetTrackerElementByName(id)
	if tracker and alive(tracker) then 
		r = r and tonumber(r) or 1
		g = g and tonumber(g) or 1
		b = b and tonumber(b) or 1
		a = a and tonumber(a) or 1
		tracker:set_color(Color(r,g,b))
		return tracker
	end
end

function Console:SetTrackerXY(id,x,y) --setting x/y only; can be used for updates, and linked to short command
	if id == "selected" then 
		id = self.selected_tracker
	end
	local tracker = self:GetTrackerElementByName(id)
	if tracker and alive(tracker) then 
		x = x and tonumber(x)
		y = y and tonumber(y)
		if x then 
			tracker:set_x(x)
		end
		if y then 
			tracker:set_y(y)
		end
	end
end

function Console:cmd_unit(subcmd,id,...)
	if subcmd == "select" then 
		
	end
end

function Console:SetUnitInfo() --unit info from debug hud
	--todo
end

function Console:RemoveTracker(id)
	local tracker 
	if id ~= nil then 
		tracker = self._persist_trackers[tostring(id)]
	end
	if tracker and alive(tracker) then 
		self._debug_hud:remove(tracker)
		self._persist_trackers[tostring(id)] = nil
		self.selected_tracker = nil
	end
end

function Console:RegisterPersistScript(id,clbk,clbk_fail,clbk_success)
	if (id ~= nil) and type(clbk) == "function" then 
		self._persist_scripts[tostring(id)] = {
			clbk = clbk,
			clbk_fail = clbk_fail,
			clbk_success = clbk_success,
			log_fail = log_fail,
			log_success = log_success,
			log_all = log_all
		}
		return true
	else
		local invalid_id = (id == nil) and "Invalid persist_script id" 
		local invalid_clbk = ((not clbk) or (type(clbk) ~= "function")) and "Invalid clbk" 
		self:Log("ERROR: RegisterPersistScript() for id [" .. tostring(id) .. "]: " .. (invalid_id or "") .. ((invalid_id and invalid_data and " and ") or "") .. (invalid_data or ""))
		return false
	end
end

function Console:RemovePersistScript(id)
	self._persist_scripts[tostring(id)] = nil -- very complex as you can see
end

--[[
function Console:cmd_adventure(toggle)
	if (toggle == true) or (toggle == false) then --if state given, set to state
		--continue to ADVENTURE
	else --if no state given, invert state
		toggle = not self._adventure
	end
	
	if self._adventure == nil then --adventure is not initiated; load adventure engine
		local result,error_message = dofile(Console.path .. "lua/adventure/adventure.lua")
		
		if error_message then 
			self:Log("Error executing adventure: " .. tostring(error_message),{color = Color.red})
			return
		elseif result then 
			self:Log("Returned from loading adventure: " .. tostring(result),{color = Color.yellow})
		end
	end
	
	self._adventure = toggle
	
end
--]]


function Console:cmd_bind(key_name,func,held,...) --func is actually a string which is fed into Console's command interpreter
	if (key_name == "help") and (not func) then
		self:Log("Syntax: /bindid [string: key_name] [function to execute; or string to parse] [optional bool: held]",{color = Color.yellow})
		self:Log("Usage: Bind a key to execute a Lua snippet or Console command.",{color = Color.yellow})
		self:Log("Example: /bind a Console:Log(\"I just pressed (a)!\")",{color = Color.yellow})
		return
	end
	if key_name then 
		if self._custom_keybinds[key_name] then --if nil or invalid func parameter then show current bind
			self:Log(tostring(key_name) .. " is already bound to [" .. self._custom_keybinds[key_name] .. "]!",{color = Color.yellow})
			return
		elseif not func then 
			self:Log("Error: You must supply a command, code, or function to execute!")
			return
		elseif func then 
			self._custom_keybinds[key_name] = {
				persist = held or false,
				func = func
			}
		end
	end
end

function Console:cmd_bindid(keybind_id,func,held,...)
--todo popup box req HoldTheKey
	if (keybind_id == "help") and (not func) then 
		self:Log("Syntax: /bind [string: keybind_id] [function to execute; or string to parse] [optional bool: held]",{color = Color.yellow})
		self:Log("Usage: Bind a key to execute a Lua snippet or Console commmand.",{color = Color.yellow})
		self:Log("Example: /bindid keybindid_taclean_left Console:Log(\"I just pressed (keybindid_taclean_left)!\")",{color = Color.yellow})
		return
	end
	if keybind_id then --todo check blt.keybinds for valid keybind registration
		if self._custom_keybinds[keybind_id] then
			self:Log(tostring(key_name) .. " is already bound to [" .. self._custom_keybinds[key_name] .. "]!",{color = Color.yellow})	
			return self._custom_keybinds[keybind_id]
		elseif not func then
			self:Log("Error: You must supply a command, code, or function to execute!")
			return
		elseif func then 
			self._custom_keybinds[keybind_id] = {
				persist = held or false,
				func = func
			}
		end
	end
end

function Console:cmd_help(cmd_name)
	if cmd_name and self.command_list[cmd_name] and string.find(self.command_list[cmd_name],"$ARGS") then 
		self:Log("Try '/" .. cmd_name .. "help'.",{color = Color.yellow}) 
	else
		self:Log("Available commands:",{color = Color.green})
		for name,_ in pairs(self.command_list) do 
			self:Log(name)
		end
	end
	self:Log("Please visit https://github.com/offyerrocker/PD2-Console/wiki for more thorough documentation.",{color = Color.yellow})
	return
end

function Console:cmd_contact()
	self:Log("Questions? Comments? You can reach me on these platforms:",{color = Color.yellow})
	self:Log("Discord: Offyerrocker#3878",{color = Color("7289da")})
	self:Log("Reddit: /u/offyerrocker",{color = Color("ff6314")})
	self:Log("Steam: /id/offyerrocker",{color = Color("2b6190")})
	self:Log("For bug reports or pull requests, I recommend you submit them to this mod's GitHub page.",{color = Color.yellow})
end

function Console:cmd_about()
	return "Info: CommandConsole Version 0.1, by Offyerrocker. \nOpen Source. Do not redistribute without permission."
--	return "About: CommandConsole is a mod designed to aid the creation and development of mods for PAYDAY 2."
end

function Console:cmd_info(target) --not implemented
	--get info about selected unit here?
end

function Console:cmd_time()
	return tostring(os.time())
end

function Console:cmd_date()
	return tostring(os.date())
end

function Console:cmd_whisper(target,message)
	if target == "help" then 
		self:Log("Syntax: /whisper [peer_id (1-4)] [message]",{color = Color.yellow})
		self:Log("Usage: Send a private message to a single player without other players reading it.",{color = Color.yellow})
		return
	end
	target = tonumber(target)
	if not target then return end --log error
	if managers.network:session() and managers.chat then
		local channel = managers.chat._channel_id
		local msg_str
		for peer_id, peer in pairs(peers) do
			if peer and (peer_id == target) and peer:ip_verified() then
				peer:send("send_chat_message", channel, message)
				local name = peer:name()
				msg_str = "[To" .. name .. "]: " .. message --todo timestamp
				managers.chat:receive_message_by_peer(channel,managers.network:session():local_peer(),msg_str,Color(0.7,0.1,0.6))
				self:Log(msg_str,{color = Color(0.7,0.1,0.6)})
				return
			end
		end			
	end
	self:Log("Private message failed")
	return
end

function Console:cmd_say(message)
	if managers.chat and managers.network then 
		local channel = managers.chat._channel_id
		local sender_name = managers.network.account:username() or "Someone"
		managers.chat:send_message(channel, sender_name, message)
		managers.chat:_receive_message(channel,sender_name,message,Color.white) --todo peerid color
	else
		self:Log("Command [/say " .. tostring(message) .. "] failed: no ChatManager present. Are you in an active lobby?")
	end
end

function Console:cmd_dofile(path)
	if path == "help" then 
		self:Log("Syntax: /dofile [string: filepath]",{color = Color.yellow})
		self:Log("Usage: Executes a file at the given path location.",{color = Color.yellow})
		return
	end
	if (not path) or path == "" then 
		self:Log("Error: /exec " .. tostring(path) .. " failed (Invalid argument to path)",{color = Color.red})
		return
	end
end

function Console:cmd_quit(skip_confirm)
	if skip_confirm == "help" then 
		self:Log("Syntax: /quit [optional bool: skip_confirm]",{color = Color.yellow})
		self:Log("Usage: Quits PAYDAY 2 after a confirm dialogue. If skip_confirm is true, does not show confirm dialogue, and quits immediately.",{color = Color.yellow})		
	end

	if (tostring(skip_confirm) == "true") then
--		Application:quit() 
--causes:
--[string "core/lib/system/coreengineaccess.lua"]:67: Application:quit(...) has been hidden by core. Use CoreSetup:quit(...) instead!
--...interesting
		CoreSetup:quit()
	end
	local menu_title = managers.localization:text("dcc_qtd_prompt_title")
	local menu_desc = managers.localization:text("dcc_qtd_prompt_desc")
	local options = {
		{
			text = managers.localization:text("dcc_qtd_cancel"),
			is_cancel_button = true
		},
		{
			text = managers.localization:text("dcc_qtd_confirm"),
			callback = callback(self,self,"cmd_quit",true)
		}
	}
	QuickMenu:new(menu_title,menu_desc,options):show()
end

function Console:cmd_teleport(x,y,z)
	local player = managers.player:local_player()
	local pos
	if x and type(x) == "string" then 
		if x == "aim" then
			pos = Console:GetTaggedPosition()
		end
	else 
		if not (x and y and z) then --teleport to aim if no arguments supplied
			pos = Console:GetTaggedPosition()
--			pos = pos or Console:GetFwdRay().position
		end
		pos = pos or Vector3(tonumber(x or 0), tonumber(y or 0), tonumber(z or 0))
	end
	if player and pos then 
		managers.player:warp_to(pos,player:rotation())
	end
end

function Console:cmd_restart(timer)
	if timer == "help" then 
		self:Log("Syntax: /restart [optional (number: timer) or (string: cancel)]",{color = Color.yellow})
		self:Log('Usage: Restarts the heist day after [timer] seconds, or cancels countdown if argument is "cancel".',{color = Color.yellow})
		return 
	end
	if not (Global.game_settings.single_player or (managers.network and managers.network:session():is_host())) then 
		self:Log("You cannot restart the game in which you are not the host!",{color = Color.red})
		return
	end

	if timer == "cancel" then 
		self._restart_timer_t = nil
		self._restart_timer = nil
		return
	end
	timer = timer and tonumber(timer) --or 5; require 0 to restart instantly?
	if not timer or timer <= 0 then 
--		self:Log("Restarted the game! JK",{color = Color.green})
		managers.game_play_central:restart_the_game()
	elseif timer then 
		self._restart_timer = nil
		self._restart_timer_t = Application:time() + timer
	--do delayed callback bs
		--callback(self,self,"cmd_restart",0)
		
--	local votemanager = managers.vote
	--if not votemanager._stopped then
--do new restart, check if host/offline
--		votemanager._callback_type = "restart"
--		votemanager._callback_counter = TimerManager:wall():time() + tonumber(timer)		
	end
end

function Console:cmd_fov(new_fov) --not used
	local player = managers.player:local_player()
	local camera = player and player:camera()
	if not camera then return "ERROR: No player/camera unit found" end
	if not new_fov then 
		return camera._camera_object._fov
	elseif camera._camera_object then
		camera:set_FOV(new_fov)
	end
end

function Console:cmd_sens(new_sens) --not used
	return "Not implemented yet"
end

function Console:cmd_sens_aim(new_sens) --not used; --currently identical to cmd_sens
	if not new_sens then 
		return sens
	end
	return "Not implemented yet"
end

function Console:cmd_ping(peerid) --not implemented
	if not peerid then 
	
	end
end

function Console:cmd_writetodisk(data,pathname) --yeah turns out there's already a BLT Util for this, SaveTable() / Utils.DoSaveTable. SO i'm just gonna redirect to that. 
	if data == "help" then 
		self:Log("Syntax: /writetodisk [table: data] [string: filepath]",{color = Color.yellow})
		self:Log("Usage: Writes a table to a file on your hard disk. Useful for saving Console log results.",{color = Color.yellow})
		return
	end
	return SaveTable(data,pathname)
--[[
	if not (data and type(data) == "table") then 
		return "Invalid data. Usage: /writetodisk data pathname"
	elseif not pathname or pathname == "" then 
		return "Invalid path. Usage: /writetodisk data pathname"
	else
		local file = io.open(pathname,"w+")
		if file then
			file:write(json.encode(self.settings))
			file:close()
			return ("Output to " .. pathname .. " successful.")
		end
	end
	--]]
end

function Console:cmd_stop(process_id) --untested; todo ban certain process names like "help" or "all" 
--todo "remove all" option
	Console._failsafe = true
	if process_id == "help" then --and self._persist_scripts.help then
		self:Log("Syntax: /stop [string: persistscript_id]",{color = Color.yellow})
		self:Log("Usage: Remove a Console-added persist script and stop it from running anymore.",{color = Color.yellow})
		--don't cancel removing the persist script, just in case some joker named their persist script "help"
	end
	return self:RemovePersistScript(process_id)
end

function Console:GetEscBehavior()
	return self.settings.esc_behavior
end

function Console:string_excise(str,s,e,replacement) --obsolete; not consistently inclusive to e
--removes the selected part of a string (non inclusive) and returns the modified string
--optional: arg "replacement" can be inserted in place of the excised substring
	replacement = tostring(replacement or "")
	local result = ""
	str = tostring(str)
	local str_len = str:len()
	local start = math.max(1,s - 1)
	local finish = math.min(str_len,e + 1)
	
	if s <= 1 then --insert at start
		result = replacement .. str:sub(finish,str_len)
	elseif finish > str_len then --insert at end
		result = str:sub(1,start) .. replacement
	else
		result = str:sub(1,s) .. replacement .. str:sub(finish,str_len)
	end
	return result
end

function Console:GetFontSize()
	return self.settings.font_size
end

function Console:GetScrollSpeed()
	return self.settings.scroll_speed
end

function Console:ClearConsole()
	for i=1,self.num_lines,1 do 
		local line = history:child("history_cmd_" .. tostring(i))
		if line and alive(line) then 
			line:remove()
		end
	end
	self.num_lines = 1
end

function Console:held(key)
	if HoldTheKey then
--		return HoldTheKey:key_held(key)
	end
	
	if not (managers and managers.hud) or managers.hud._chat_focus then
		return false
	end
	
	key = tostring(key)
	if key:find("mouse ") then 
		if not key:find("wheel") then 
			key = key:sub(7)
		end
		return Input:mouse():down(Idstring(key))
	else
		return Input:keyboard():down(Idstring(key))
	end
end

function Console:_shift()
	local k = Input:keyboard()

	return k:down(Idstring("left shift")) or k:down(Idstring("right shift")) or k:has_button(Idstring("shift")) and k:down(Idstring("shift"))
end

function Console:_ctrl()
	local k = Input:keyboard()
	return k:down(Idstring("left ctrl")) or k:down(Idstring("right ctrl")) or k:down(Idstring("ctrl"))
end

function Console:ToggleConsoleFocus(focused)
	if not managers.hud then return end
	if (focused == true) or (focused == false) then 
		self._focus = focused
	else
		self._focus = not self._focus
	end
	self._panel:set_visible(self._focus)

	if self._focus then 
		self._enter_text_set = false
		self._ws:connect_keyboard(Input:keyboard())

		self._panel:child("input_text"):key_press(callback(self, self, "key_press")) --i have no idea how this works but it does
		self._panel:child("input_text"):key_release(callback(self, self, "key_release"))

	else
		self._ws:disconnect_keyboard()
	
	end
end

function Console:GetFwdRay(item)
	local player = managers.player:local_player()
	local result
	if player then 
		result = player:movement():current_state()._fwd_ray
		if item then --custom index
			result = result and result[item] or result
		end
	end
	return result
end

function Console:SetFwdRayUnit(unit) 
	if unit and alive(unit) and unit:character_damage() then --and not filtered_type(unit)
		self.tagged_unit = unit
	else
		self.tagged_unit = nil
	end
end

function Console:GetTaggedPosition()
	return self.tagged_position
end

function Console:GetTaggedUnit()
	return self.tagged_unit
end

function Console:GetCharList()
	--local region = System:region() or "US" or whatever i guess
	if not self._console_charlist then 
		self._console_charlist = self:BuildCharList(region)
	end
	return self._console_charlist
end

function Console:BuildCharList(region) --i'm either a genius or an idiot, depends on who you talk to
--This is set up for US keyboards. Sorry, I don't know how else to do it!
	local raw = {
		alpha = { ["abcdefghijklmnopqrstuvwxyz"] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"},
		numeric = {["1234567890"] = "!@#$%^&*()"},
		symbol = {["-=[]\\;,./"] = "_+{}|:<>?"},
--		tilde = {["`"] = "`"}, --disabled for now
		special = {["'"] = "\""}
	}
	
	local charlist = {}
	
	for cat,tbl in pairs(raw) do 
		for lowercase,uppercase in pairs(tbl) do 
			for i=1,string.len(lowercase),1 do
				local bef = string.sub(lowercase,i,i)
				local aft = string.sub(uppercase,i,i)
				local ids = bef and Idstring(bef)
				if ids then 
					charlist[tostring(ids)] = {
						lowercase = bef,
						uppercase = aft
					}
				end
			end
		end
	end

	return charlist
end

function Console:esc_key_callback() --temp disabled until i figure out how to safely temporarily disable esc>menu input; currently will only close console

	local text = Console._panel:child("input_text")
	local behavior = 3 --tonumber(self:GetEscBehavior())
	
	if behavior == 1 then -- clear text
		text:set_selection(0,0)
		text:set_text("")
	elseif behavior == 2 then -- hybrid (if not empty then clear text; if empty then hide console) 
		if text:text():len() <= 0 then 
			self:ToggleConsoleFocus(false)
		else
			text:set_selection(0,0)
			text:set_text("")
		end
	elseif behavior == 3 then -- close (hide console)
		self:ToggleConsoleFocus(false)
	elseif behavior >= 4 then -- combo (clear text + hide console)
		text:set_selection(0,0)
		text:set_text("")
		self:ToggleConsoleFocus(false)
	end
end

function Console:enter_key_callback(from_history) --interpret cmd input from the "Enter" key
	local auto_evaluate = false --and self.settings.auto_evaluate --should be taken from setting
	local v_margin = 6 or self.v_margin --done margin, not normal v margin
	local panel = self._panel
	local input_text = panel:child("input_text")
	local history_data,history_func,history_success,history_result
	local cmd = input_text:text() --input string to work with

	local orig_cmd = cmd --copy original input string for logging purposes; cmd will be extensively changed in following command parsing
	input_text:set_text("") --wipe input box
	
						
		
	if from_history and self.selected_history then
		history_data = self.command_history[self.selected_history] or {}
		if not (history_data.name and history_data.name == cmd) then
			self:Log("Attempt to run command " .. tostring(cmd) .. " from history failed: modified cmd. Only use CTRL-ENTER for re-executing command history!",{color = Color.red})
			return
		end
	elseif cmd == "//" then --note: no whitespace removal, as this conditional is before that bit. string must match EXACTLY
		history_data = self.command_history and self.command_history[#self.command_history] or {}
		cmd = history_data.name
		from_history = true
		if not cmd then 
			self:Log("Attempt to run repeat command (using //) from history failed: invalid command name in history.",{color = Color.red})
			return 
		end
	end
	
	if history_data then 
		history_func = history_data.func
		history_success,history_result = pcall(history_func)
		self:Log("> " .. tostring(cmd),{new_cmd = true,color = Color.white:with_alpha(0.7),h_margin = 0})
		if history_success then
			if (history_result ~= nil) then 
				self:Log("Command successfully ran from history with result:",{color = Color.blue})
				self:Log(tostring(history_result),{color = Color(0.1,0.5,1)})
			else
				self:Log("Command successfully ran from history with no result",{color = Color.yellow})
			end
		else
			self:Log("Command run from history failed",{color = Color.red}) --todo get error from when loadstring() was called at original command
		end
		table.insert(self.command_history,{name = cmd, func = history_func}) --save to history as last used command
		self.selected_history = nil --reset selected command_history 
		return
	elseif from_history then
		self:Log("Attempt to run command " .. tostring(cmd) .. " from history failed: invalid history data.",{color = Color.red})
		return
		--don't clear selected command history if failure
	end
	self.selected_history = nil --reset selected command_history 

	local is_command = false
	
	local input_len = string.len(cmd)
	
	if input_len <= 0 then 
		return --invalid/empty input
	else
		--check for empty space before cmd and remove it
		local space_len = 0 --index 
		for i = 1, input_len,1 do
			if string.sub(cmd,i,i) == " " then --note to self: add other future blacklisted "prefix" characters and check against blacklist table here
				space_len = i
			else
				break --if next character is not a space
			end
		end
		if space_len > 0 then 
			cmd = string.sub(cmd,space_len) 
		end
	end
	input_len = string.len(cmd) --set len again
	if cmd == "" or (input_len <= 0) then 
		return --check for invalid cmd again since we just changed it
	end

	self:Log("> " .. cmd,{new_cmd = true,color = Color.white:with_alpha(0.7),h_margin = 0}) --log the input str to console

	if string.sub(cmd,1,1) == "/" then --command indicator
		is_command = true
		
		if string.match(cmd,"'") then 
			self:Log("Error: Illegal character (') in shortcommand",{color = Color.red}) 
			return 
		end
		
		cmd = string.sub(cmd,2)
		local args = string.split(cmd," ") --parse args from input string
		local cmd_id = args and args[1] --
		local command = cmd_id and self.command_list[cmd_id] 
		local argument_string = args[2]
		if argument_string then 
			argument_string = "'" .. argument_string .. "'"
		else
			argument_string = ""
		end
		for k,argument in pairs(args) do 
			if k > 2 and (argument ~= "") then 
				--basically table.concat but i need to ignore the first argument because it's actually the "function"
				argument_string = argument_string .. ",'" .. argument  .. "'"
			end
		end
		
		if command then 
			cmd = string.gsub(command,"$ARGS",argument_string) --replace original string, and preserve "command" for logging the original function name (eg. "Console:cmd_about()")
--			self:Log("Writing command " .. tostring(command) .. " to result " .. tostring(cmd))
		elseif cmd_id then 
			self:Log("No such command found: " .. "/" .. tostring(cmd_id),{color = Color.red})
			return
		else
			self:Log("Error: empty command string",{color = Color.red})
			return 
		end
	end
	local success,result,func,error_message
	if auto_evaluate then 
		func,error_message = loadstring("Console:evaluate(" .. cmd .. ")")
	else
		func,error_message = loadstring(cmd)
	end
	if error_message or not func then 
		self:Log("Command " .. tostring(func or "") .. " failed: " .. error_message,{color = Color.red})
	else
		success,result = pcall(func) --!
		if success then
			if result ~= nil then 
				self:Log(result,{color = Color(0.1,0.5,1)})
			elseif not is_command then
				self:Log("Done",{color = Color.yellow})
			elseif is_command then
				self:Log("Done (command)",{color = Color.yellow})
			end
		else -- command fail
			self:Log("Command failed (no error given) " .. (result and (" with result:[" .. tostring(result) .. "]") or ""),{color = Color.red})
		end
	end
	table.insert(self.command_history,{name = is_command and orig_cmd or cmd, func = func})
end

function Console:key_press(o,k)
	local panel = self._panel
	local text = panel:child("input_text")
	local debug_text = panel:child("debug_text")
	self.input_interval_done = false
	
	local skip_set_pressed = false --if true, does not set self._key_pressed to k (basically, just ignores this key input)
	local revert_alpha = false --if keys that are not up-arrow or down-arrow are pressed, this is set to true, and alpha is set to 1.0 once more
	
	self.input_t = 0
	
	local ctrl_held = self:_ctrl() --and they said i didn't have any self control
	
	local clipboard = Application:get_clipboard()
	local s,e = text:selection()
	if not (s and e) then 
		text:set_selection(0,0)
		s,e = text:selection()
	end
--	local n = utf8.len(text:text()) --current cmd string length
--	local d = math.abs(e-s) --selection length

	if k == Idstring("enter") then 
		if self._skip_first then 
			self._skip_first = false
			return
		else
			self:enter_key_callback(ctrl_held)
		end
	end
	local clipb_end
	local current = text:text()
	local current_len = string.len(current)
	if k == Idstring("delete") then 
		revert_alpha = true
		--can autorepeat
	elseif k == Idstring("insert") then 
		revert_alpha = true
--		text:set_text(self:string_excise(current,s,e,clipboard))
		text:replace_text(clipboard)
		clipb_end = clipboard and (s + string.len(clipboard)) or s --get end of clipboard, or use caret position before clipboard
		text:set_selection(clipb_end,clipb_end) --set caret to end of clipboard
	elseif k == Idstring("left") then 
		revert_alpha = true
		--can autorepeat
	elseif k == Idstring("right") then 
		revert_alpha = true
		--can autorepeat
	elseif k == Idstring("up") then
	elseif k == Idstring("down") then 
	elseif k == Idstring("home") then 
		revert_alpha = true
		--can autorepeat
	elseif k == Idstring("end") then 
		revert_alpha = true
		--can autorepeat
	elseif k == Idstring("page up") then 
		--can autorepeat
	elseif k == Idstring("page down") then 
		--can autorepeat
	elseif k == Idstring("esc") and type(self._esc_callback) ~= "number" then		
		self:esc_key_callback()
	elseif k == Idstring("a") and ctrl_held then --select all; do not autorepeat
		revert_alpha = true
		if current_len > 0 then
			text:set_selection(0,current_len)
		end
		skip_set_pressed = true
	elseif k == Idstring("v") and ctrl_held then --do not autorepeat; identical to insert
		revert_alpha = true
--		text:set_text(self:string_excise(current,s,e,clipboard))
--		text:set_selection(s,s + string.len(clipboard)) --select newly pasted clipboard contents
		text:replace_text(clipboard)
		clipb_end = clipboard and (s + string.len(clipboard)) or s --get end of clipboard, or use caret position before clipboard
		text:set_selection(clipb_end,clipb_end) --set caret to end of clipboard
		
		skip_set_pressed = true  --do not set key pressed or add "v" char
	elseif k == Idstring("z") and ctrl_held then 
		revert_alpha = true
		skip_set_pressed = true --same; ctrl-z is not implemented yet
	else
--		return
	end
	if revert_alpha then 
		text:set_alpha(1)
	end
	
	if not skip_set_pressed then 
		self._key_pressed = k
	end
end

function Console:update_key_down(o,k,t)
	local panel = self._panel
	
	if not (k and self._key_pressed) then return end
	local t = Application:time()
	if self.input_t <= 0 then 
		self.input_t = t
	elseif self.input_t + (self.input_interval_done and self.input_interval or self.input_interval_initial) < t then 
		self.input_t = t
		self.input_interval_done = true
	else
		return
	end
	
	local num_commands = #self.command_history
	local text = panel:child("input_text")	
	local history = panel:child("command_history_frame"):child("command_history_panel")
	local new_char
	local shift_held = self:_shift()
	local ctrl_held = self:_ctrl()
	local s,e = text:selection()
	
	local n = utf8.len(text:text())
	
	local current = text:text()
	local new_text = ""
	local current_len = string.len(current) --todo figure out how this is different from ut8.len()

	if k == Idstring("space") then 
		new_char = " "
	else
		local ids = self:GetCharList()[tostring(k)]
		if ids then 
			if shift_held then 
				new_char = tostring(ids.uppercase or "_")
			else
				new_char = tostring(ids.lowercase or "_")
			end
		end
	end
	if new_char then 
	--[[	
		if (s == e) then --insert text at (after) caret
			if s >= current_len then --insert at end; implicitly s > 1
				text:set_text(current .. new_char)
				text:set_selection(s+1,s+1)
				self:Log("==")
			elseif s <= 1 then --insert at start
--				text:set_text(new_char .. current:sub(1,current_len))
				text:replace_text(new_char)
				text:set_selection(s+1,s+1) --todo TEXT-INS mode?
				self:Log("<=")
			elseif s < current_len then --insert somewhere in middle
				text:set_text(current:sub(1,s) .. new_char .. current:sub(s + 1,current_len))
				text:set_selection(s+1,s+1)
				self:Log("<")
			end
			text:replace_text(new_char)
			text:set_selection(s+1,s+1)
		else --if s ~= e then --replace selection
			self:Log("else")
--			text:set_text(self:string_excise(current,s,e,new_char))
		end
			--]]
		self.selected_history = false
		text:replace_text(new_char)
		text:set_selection(s+1,s+1)
		text:set_alpha(1)
	else
		if k == Idstring("backspace") then --delete selection or text character behind caret
			if s == e and s > 0 then
				text:set_selection(s - 1, e)
			end

			text:replace_text("")
			
		elseif k == Idstring("delete") then --delete selection or text character after caret
			
			if s == e and s < n then
				text:set_selection(s, e + 1)
			end

			text:replace_text("")

		elseif k == Idstring("insert") then 
			--copypaste should not auto-repeat
		elseif k == Idstring("left") then 
			if shift_held then 
				if s == e then 
					self.selection_dir = -1
				end

			--elseif control_held then find next space/char
				if (s > 0) and (self.selection_dir < 0) then -- forward select (increase selection)
					text:set_selection(s-1,e)
				elseif (e > 0) and (self.selection_dir > 0) then --backward select (decrease selection) 
					text:set_selection(s,e-1)
				end
			else --move caret
				if (s < e) then --cancel selection and move caret left
					text:set_selection(s,s)
				elseif (s > 0) then --else if no selection then keep caret left
					text:set_selection(s - 1, s - 1)
				end
			end
			
			self._caret_blink_t = t

			self._panel:child("caret"):set_visible(true)			
		elseif k == Idstring("right") then 
			if shift_held then 
				if (s == e) then --if no selection then set direction right
					self.selection_dir = 1				
				end
				if (e < n) and (self.selection_dir > 0) then --forward select (increase selection)
					text:set_selection(s,e+1)
				elseif (e > s) and (self.selection_dir < 0) then --backward select (decrease selection)
					text:set_selection(s + 1,e)	
				end
			elseif ctrl_held then 
			--elseif control_held then find next space/char
			else
				if s < e then --cancel selection and keep caret right
					text:set_selection(e,e)
				elseif s < n then --move caret right
					text:set_selection(s + 1, s + 1)
				end
			end
			self._caret_blink_t = t
			self._panel:child("caret"):set_visible(true)
		elseif k == Idstring("down") then 
			new_text = false
			if self.selected_history then
				self.selected_history = (self.selected_history + 1) % num_commands			
			else
				self.command_history[0] = {name = current, func = nil}
				self.selected_history = 1
			end
			
			local herpaderp = self.command_history[self.selected_history] --todo rename var
			new_text = herpaderp and herpaderp.name
			
			if (self.selected_history <= 0) and not herpaderp then
				self.selected_history = false
			end
			
			
--			new_text = self.command_history[self.selected_history]
			
--			new_next = new_text and new_text.name
			if new_text then 
				if not self.selected_history then 
--					self:Log("ERROR! No self.selected_history for DOWNARROW input",{color = Color.red})
				elseif self.selected_history <= 0 then
					text:set_alpha(1)
					text:set_text(new_text)
--					self.command_history[0] = {name = current; func = nil} --no func, to disable CTRL-ENTER
				else
					text:set_alpha(0.5)
					text:set_text(new_text)
				end

				current_len = new_text and string.len(tostring(new_text))
				
--do not change selection				
				--text:set_selection(current_len,current_len)
--				self:Log("Success for selection index " .. tostring(self.selected_history))
			else
--				self:Log("No new_text for selection index " .. tostring(self.selected_history),{color = Color.yellow})
			end
			
			--[[
		
			if not self.selected_history then 
				self.command_history[0] = {name = current, func = nil}
				self.selected_history = 1 --set at newest command
				
			else

				if self.selected_history <= 0 then --revert to line in progress
					self.selected_history = 0
					new_text = self.command_history[self.selected_history]
					if new_text then 
						new_text = new_text.name
						text:set_text(new_text)
						text:set_alpha(1)
						return
					end
					
				else
					if self.selected_history >= num_commands then -- next command
						self.selected_history = 1
					elseif num_commands > 1 then 
						self.selected_history = self.selected_history + 1
						new_text = new_text and new_text.name --set to history command
					end

					new_text = self.selected_history and self.command_history[self.selected_history] -- get history command
					
					--doing history, so lower alpha and update input
					--then update selection caret
					if new_text then 
						new_text = new_text.name
						text:set_alpha(0.5)
						text:set_text(new_text)
						current_len = string.len(new_text)
						text:set_selection(current_len,current_len)
					end
					
				end
			end
			--]]
		elseif k == Idstring("up") then 
			
			new_text = false
			
			if self.selected_history then 
				if (self.selected_history - 1) >= 0 then 
					self.selected_history = self.selected_history - 1
				else
					self.selected_history = num_commands --set to max if below zero
				end
			else --set cmd history
				self.command_history[0] = {name = current, func = nil}
				self.selected_history = num_commands
			end
				
			new_text = self.command_history[self.selected_history] and self.command_history[self.selected_history].name
			
			if self.selected_history <= 0 and not new_text then 
				self.selected_history = false
			end
			
			if new_text then 
				if not self.selected_history then 
--					self:Log("No self.selected_history for UPARROW input",{color = Color.red})
				elseif self.selected_history <= 0 then 
					text:set_alpha(1)
					text:set_text(new_text)
				else
					text:set_alpha(0.5)
					text:set_text(new_text)
				end
				
			else
--				self:Log("No new_text for selection_index " .. tostring(self.selected_history),{color = Color.yellow})
			end
			
				
--			current_len = new_text 
--				self.selected_history - (self.selected_history + 1) 
			

	--[[
			if not self.selected_history then --evaluate count
				self.command_history[0] = current
				self.selected_history = num_commands --set at oldest command
			elseif self.selected_history <= 1 then --reached minimum; reset to 0; do not wraparound order
				new_text = self.command_history[0]
				if new_text then 
					text:set_text(new_text)
					self.command_history[0] = nil
				end
				self.selected_history = false
				return 
			elseif num_commands > 1 then --and self.selected_history > 1 by default 
				self.selected_history = self.selected_history - 1
			end
		
			new_text = self.selected_history and self.command_history[self.selected_history]
			new_text = new_text and new_text.name
			if new_text then 
				text:set_alpha(0.5)
				text:set_text(new_text)
				current_len = string.len(new_text)
				text:set_selection(current_len,current_lent)
			end
			--]]
		
		
		
		--[[
		
			if not self.selected_history then 
				self.selected_history = num_commands --set at oldest command
				self.command_history[0] = current
			else
				if self.selected_history <= 1 then 
					self.selected_history = false
					new_text = self.command_history[0]
					if new_text then 
						text:set_text(new_text) 
					end
					self.command_history[0] = current
				elseif num_commands > 1 then --and self.selected_history > 1 by default 
					self.selected_history = self.selected_history - 1
				end
			end
			
			new_text = self.selected_history and self.command_history[self.selected_history]
			new_text = new_text and new_text.name
			if new_text then 
				text:set_alpha(0.5)
				text:set_text(new_text)
				current_len = string.len(new_text)
				text:set_selection(current_len,current_lent)
			end
			
			--]]
		elseif k == Idstring("home") then 
			text:set_selection(0, 0)
		elseif k == Idstring("end") then 
			text:set_selection(n, n)
		elseif k == Idstring("page down") then 
			history:set_y(history:y() - (Console.settings.scroll_page_speed))
			--move history window up by 14 * (math.floor(frame:h() / 14))
			self:refresh_scroll_handle()
		elseif k == Idstring("page up") then 
			history:set_y(history:y() + (Console.settings.scroll_page_speed))
			self:refresh_scroll_handle()
			--same as pgup except move down
		elseif k == Idstring("esc") and type(self._esc_callback) ~= "number" then
			return
		else
			return
		end

	end

end

function Console:key_release(o,k)
	self.input_interval_done = false
	if k == self._key_pressed then 
		self._key_pressed = nil
	end
end

function Console:evaluate(info) --UNUSED
--this is only for enabling simple Lua code like "1+1" to return 2 rather than requiring "return 1+1" in order to return 2
--without this, "1+1" will yield an error, and code that returns something will still need a value returned in order to display a result
	self._last_result = info
	return info
end

function Console:update(t,dt)
	self:update_custom_keybinds(t,dt)

	self:update_scroll(t)
	
	self:update_hud(t,dt)
	
	self:update_persist_scripts(t,dt)
	
	self:update_restart_timer(t,dt)
end

function Console:update_persist_scripts(t,dt)
	if not self._persist_scripts then return end
	for id, data in pairs(self._persist_scripts) do 
		if data and type(data) == "table" then 
			local success_1,result_1,success_2,result_2
			if data.clbk then 
				success_1,result_1 = pcall(data.clbk) --execute given script
			end
			if success_1 then 
				if result_1 and data.clbk_success then 
					success_2,result_2 = pcall(data.clbk_success)
				end
			elseif data.clbk_fail then 
				success_2,result_2 = pcall(data.clbk_fail)				
			end
			local clbk_1_msg,clbk_2_msg
			
			if data.log_fail or data.log_all then 
				if not success_1 then 
					clbk_1_msg = "clbk failed with result " .. tostring(result_1)
				end
				if clbk_fail and not success_2 then 
					clbk_2_msg = "clbk_fail failed with result " .. tostring(result_2)
				end
			end
			if data.log_success or data.log_all then
				if success_1 then 
					clbk_1_msg = "clbk succeeded with result " .. tostring(result_1)
				end
				if clbk_success and success_2 then
					clbk_2_msg = "clbk_success succeeded with result " .. tostring(result_2)
				end
				
			end
			--[[	
			local clbk_1_msg = (success_1 and " successful with result [" .. tostring(result_1) .. "]") or (" unsuccessful.")
			local clbk_2_msg = (success_1 and clbk_success and " clbk_success ") or (not success_1 and data.clbk_fail and " clbk_fail ")
			if clbk_2_msg then 
				clbk_2_msg = clbk_2_msg .. " was " .. (success_2 and "successful " or "unsuccessful")
				clbk_2_msg = clbk_2_msg .. " with result [" .. tostring(result_2) .. "]"
			else
				clbk_2_msg = ""
			end	
			--]]
			if (clbk_1_msg or clbk_2_msg) then 
				self:Log("Persist script [" .. id .. "]  was " .. (clbk_1_msg or "") .. (clbk_2_msg or ""))
			end
		else
			self:Log("Invalid persist data")
			--invalid persist data
		end
	end
end

function Console:update_hud(t,dt)
	local hud = self._debug_hud
	if not hud then return end
	local name = hud:child("info_unit_name")
	local hp = hud:child("info_unit_hp")
	
	local viewport_cam = managers.viewport:get_current_camera()

--		self._hud_access_camera:draw_marker(i, self._workspace:world_to_screen(cam, pos)) -- returns vector3
	
	local fwd_ray = self:GetFwdRay() or {}
	
	local unit = self.tagged_unit or fwd_ray.unit
	local is_tagged = self.tagged_unit and true or false
	local pos = self.tagged_position or fwd_ray.position
	
	local player = managers.player:local_player()
	if player then 
		--create look + pos coordinates
	end
	
	--todo application debug draw 3d shapes for unit "beam"
	--todo draw hitboxes
	local unit_marker = hud:child("marker")
	if unit and alive(unit) and unit:character_damage() and unit:base() then 
		local unit_pos = unit:position()

		local head_pos
		local head_obj = unit:get_object(Idstring("Head")) 
		if head_obj then 
			head_pos = head_obj:position()
		end
		
		local top_pos, bot_pos
		if head_pos then 
			top_pos = self._ws:world_to_screen(viewport_cam,head_pos)
		end
		if unit_pos then 
			bot_pos = self._ws:world_to_screen(viewport_cam,unit_pos)
		end
--[[
		if top_pos and bot_pos then 
			local center = math.abs(bot_pos.y - top_pos.y)
			unit_marker:set_h(center)
			unit_marker:set_w(center * 0.66)
			unit_marker:set_x(top_pos.x - (unit_marker:w() / 2))
			
			unit_marker:set_y(top_pos.y)
		else
		end
		--]]
	
		local hud_pos = (top_pos or bot_pos) or {x=-500,y=-500}
--			local hud_pos = self._ws:world_to_screen(viewport_cam,head_pos or unit_pos) or {x = -1000,y = 300}
		unit_marker:set_center(hud_pos.x,hud_pos.y)
	
--		unit_marker:set_y(hud_pos.y)
		
		name:set_text(tostring(unit:base()._tweak_table or "ERROR"))
		name:set_color(Color.yellow)
		hp:set_text(tostring(unit:character_damage()._health))
		hp:set_color(Color.yellow)
--		unit_marker:set_color(is_tagged and Color.red or Color.white)
		unit_marker:set_alpha(is_tagged and 1 or 0.3)
--		unit_marker:set_visible(true)
	else
		unit_marker:set_alpha(0)
		name:set_text("NO DATA")
		name:set_color(Color.red:with_alpha(0.3))
		hp:set_text("NO DATA")
		hp:set_color(Color.red:with_alpha(0.3))
--		unit_marker:set_visible(false)
	end
	
end

function Console:update_custom_keybinds(t,dt)

	for keybind_id,keybind_data in pairs(self._custom_keybinds) do 
		local k_result,k_fail
		local held = HoldTheKey and HoldTheKey:Keybind_Held(keybind_id)
		if keybind_data and type(keybind_data) == "table" then
			if held and ((not self._keybind_cache[keybind_id]) or keybind_data.persist) then
				if keybind_data.clbk then 
					if type(keybind_data.clbk) == "function" then 
						k_result,k_fail = pcall(keybind_data.clbk)
						if not (k_result or keybind_data.persist) then 
							self:Log("Keybind [" .. keybind_id .."] execution failed",{color = Color.red})
						end
					end
				end
			end
			self._keybind_cache[keybind_id] = held
		end
	end
	
end

function Console:update_restart_timer(t,dt)
	--if host then blah blah blah
	if self._restart_timer_t then --time at which heist will restart
		local time_left = math.floor(self._restart_timer_t - t) --seconds left to restart
		if (not self._restart_timer) or (self._restart_timer - time_left) >= 1 then --output only once, not every update
			self._restart_timer = self._restart_timer or time_left 
			self._restart_timer = time_left
			self:Log("RESTARTING IN " .. string.format("%i",tostring(time_left)) .. " SECONDS.",{color = Color.yellow})
		end
		if time_left <= 0 then 
			managers.game_play_central:restart_the_game()
			self._restart_timer_t = nil
		end
	end
end

function Console:update_scroll(t,dt)
--todo if selected unit then update marker to unit
	local panel = self._panel
	if not panel then return end
	if self._focus then 
		local scroll_handle = panel:child("scroll_handle")
		--cursor blink
		local input_text = panel:child("input_text")
		local cursor = panel:child("cursor")

		local frame = panel:child("command_history_frame")
		local history = frame:child("command_history_panel")
		local font_size = self:GetFontSize()
		local v_margin = self.v_margin
		local console_h = frame:h()
		local mwu = "mouse wheel up"
		local mwd = "mouse wheel down"
		local scroll_speed = self:GetScrollSpeed()
		
		self:upd_caret(t)
		self:update_key_down(input_text,self._key_pressed,t)
		
		local new_y
--		local y_sign
		if self:held(mwu) then --console scroll
			new_y = math.max(history:y() - scroll_speed,-history:h())
			
--			y_sign = math.sign(new_y)
			history:set_y(new_y)
			self:refresh_scroll_handle()
		elseif self:held(mwd) then 
			new_y = math.min(history:y() + scroll_speed,0)
--			y_sign = math.sign(new_y)
			history:set_y(new_y)
			self:refresh_scroll_handle()
		end
	end
end

function Console:upd_caret(t) --position, selection and blink
	local panel = self._panel
	
	local input_text = panel:child("input_text")
	local caret = panel:child("caret")
	local selection_box = panel:child("selection_box")
	local s,e = input_text:selection()
	
	local x,y,w,h = input_text:selection_rect()
	
	if s == 0 and e == 0 then 
		x = input_text:world_x()
		y = input_text:world_y()
	end
	
	if s == e then 
		w = 0
	end
	
	if self.selection_dir > 0 then --selection going right
		caret:set_x(x + w + -1)
	elseif self.selection_dir < 0 then --selection going left
		caret:set_x(x - 1)
	end
	caret:set_y(y)
	
	h = input_text:font_size()
	
	selection_box:set_world_shape(x,y + 2, w, h - 4)
	
	if self._caret_blink_t + self.caret_blink_interval < t then 
		self._caret_blink_t = t
		caret:set_visible(not caret:visible())
	end

end

function Console:refresh_scroll_handle()
	--local lines_ratio = self.lines_ratio
	local frame = self._panel:child("command_history_frame")
	local history = frame:child("command_history_panel")
	--return Console._panel:child("command_history_frame"):child("command_history_panel"):h()
	local page_h = frame:h()
	local total_h = history:h()
	local history_y = history:y()
	
	local size_ratio = page_h / total_h
	
	
--	local num_lines = self.num_lines
	
	
	local scroll_handle = self._panel:child("scroll_handle")
--	local history_tracker = self:CreateTracker("history_debug")
	
	scroll_handle:set_h(math.max(page_h * size_ratio,8))
	scroll_handle:set_y(history_y * size_ratio)
	
--	history_tracker:set_text(history_y)
	--[[
--	local scroll_tracker = self:CreateTracker("scroll_debug")
--	scroll_tracker:set_text(tostring(num_lines))
	scroll_handle:set_y(page_h - (history_y * size_ratio))
	scroll_handle:set_h(console_h / Console.num_lines)
	scroll_handle:set_y(scroll_speed * (history:y() / (scroll_speed * Console.num_lines)))

	scroll_handle:set_h(console_h / Console.num_lines)
	scroll_handle:set_y(scroll_speed * (history:y() / (scroll_speed * Console.num_lines)))
--]]
end

function Console:logall(obj,max_amount)
	local type_colors = {
		["function"] = Color.blue,
		["string"] = Color.grey,
		["number"] = Color.orange,
		["Vector3"] = Color.purple,
		["table"] = Color.yellow,
		["userdata"] = Color.red
	}
	
	if not obj then 
		self:Log("Nil obj to argument1 [" .. tostring(obj) .. "]",{color = Color.red})
		return
	end
	--[[ old method using globals; i realised that this was a bad idea.
	if _G[tostring(global_failsafe)] == nil then 
		self:Log("No global failsafe for argument2 [" .. tostring(global_failsafe) .. "]",{color = Color.red})
		return
	end
	local before_state = _G[tostring(global_failsafe)]
	while _G[tostring(global_failsafe)] == before_state do
	--]]
	local i = max_amount and 0
	Console._failsafe = false
	while not Console._failsafe do 
		if i then 
			i = i + 1
			if i > max_amount then
				self:Log("Reached manual log limit " .. tostring(max_amount),{color = Color.yellow})
				return
			end
		end
		for k,v in pairs(obj) do 
			local data_type = type(v)
			self:Log("Index [" .. tostring(k) .. "] : [" .. tostring(v) .. "]",{color = type_colors[data_type]})
		end
		Console._failsafe = true --process can be stopped with "/stop" if log turns out to be recursive or too long in general
	end
	
	
	
end

local orig_togglechat = MenuManager.toggle_chatinput
function MenuManager:toggle_chatinput(...) --prevent the chat window from showing up when using console
--if not Console:enabled() then return orig_togglechat(self,...) end
	if not Console._focus then 
		if Global.game_settings.single_player then
--			return
		end
		if Application:editor() then
			return
		end

		if SystemInfo:platform() ~= Idstring("WIN32") then
			return
		end

		if self:active_menu() then
			return
		end

		if not managers.network:session() then
--			return
		end

		if managers.hud then
			managers.hud:toggle_chatinput()

			return true
		end
	end
end

function Console:TagPosition(position)
	if not position then 
		return 
	end
	local tagged
	if type(position) == "string" then 
		if position == "aim" then 
			tagged = Console:GetFwdRay("position")
		end
	else
		tagged = position
	end
	self.tagged_position = tagged
	
end

function Console:SetupHitboxes()
	local hitboxes = callback(Console,Console,"GenerateHitboxes")
	Console:RegisterPersistScript("hitboxes",hitboxes)
end

function Console:GenerateHitboxes(mask,radius,distance) --slight misnomer, it just generates the debug shapes of the hitboxes, not the actual hitboxes themselves
	local slot_mask = managers.slot:get_mask(mask or "enemies" or "bullet_impact_targets")
	local player = managers.player:local_player()
	if not player then return end
	local cam = player:camera():camera_object()
	local center = Vector3(0,0)
	radius = tonumber(radius or 0.9)
	distance = tonumber(distance or 1000)
	size = 10
	
	local tagged_pos = self:GetTaggedPosition()
	if tagged_pos then --and (type(Console.tagged_position) == "Vector3") then 
		self._tagworld_brush:sphere(tagged_pos,100)
	end
	local tagged = self:GetTaggedUnit()
	if tagged and alive(tagged) then 
		self._tagunit_brush:cylinder(tagged:position(),tagged:position() + Vector3(0,0,200),100)
	else
		self.tagged_unit = nil
	end
	
	--props with enabled damage extension: eg. exploding barrels, tripmines, glass, saw-able safety deposit boxes
	local objects = World:find_units("camera_cone", cam, center, radius, distance, slot_mask)
	for _,unit in pairs(objects) do 
		if unit and alive(unit) and unit:damage() then
			if tagged and alive(tagged) and tagged:key() and (tagged:key() == unit:key()) then
				--do nothing
			else
	--			local chardamage = unit:character_damage()
	--			local bodyplate = chardamage and chardamage._ids_plate_name
	--			local bodyplate = unit:get_object(Idstring("body_plate"))
	--			if bodyplate then 
	--			Draw:brush(Color.red:with_alpha(0.5),2):sphere(unit:position(),10)
				Console._tagunit_brush:sphere(unit:position(),8)
				
			end
		end
	end
		
end

Hooks:Add("LocalizationManagerPostInit", "commandprompt_addlocalization", function( loc )
	local path = Console.loc_path
	
	for _, filename in pairs(file.GetFiles(path)) do
		local str = filename:match('^(.*).txt$')
		if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
			loc:load_localization_file(path .. filename)
			return
		end
	end
	loc:load_localization_file(path .. "localization/english.txt")
end)	

Hooks:Add("MenuManagerInitialize", "commandprompt_initmenu", function(menu_manager)
	MenuCallbackHandler.commandprompt_tagunit = function(self)
		local unit = Console:GetFwdRay("unit")
		Console:SetFwdRayUnit(unit)
	end
	MenuCallbackHandler.commandprompt_tagposition_aim = function(self)
		Console:TagPosition("aim")
	end
	MenuCallbackHandler.commandprompt_resetsettings = function(self) --button
		
	end
	MenuCallbackHandler.commandprompt_setescbehavior = function(self,item) --multiplechoice
		Console.settings.esc_behavior = item:value()
	end
	MenuCallbackHandler.commandprompt_toggle_1 = function(self,item) --slider
		--save?
	end
	MenuCallbackHandler.commandprompt_setfontsize = function(self,item) --slider
		Console.settings.font_size = tonumber(item:value())
		--save?
	end
	MenuCallbackHandler.commandprompt_toggle = function(self) --keybind
		if (Input and Input:keyboard() and not Console:_shift()) then 
			Console:ToggleConsoleFocus()
		end
	end
	MenuHelper:LoadFromJsonFile(Console.options_path, Console, Console.settings) --no settings, just the two keybinds
end)

function Console:SaveKeybinds()
	
end

function Console:LoadKeybinds()
	
end

function Console:Load()
	local file = io.open(self.save_path, "r")
	if (file) then
		for k, v in pairs(json.decode(file:read("*all"))) do
			self.settings[k] = v
		end
	else
		self:Save()
	end
end

function Console:Save()
	local file = io.open(self.save_path,"w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end


function Console:Calcium(a,b) --just fooling around with bones; does nothing of value atm
	if not Console.tagged_unit then
		self:Log("No tagged unit",{color = Color.red})
		return
	end
	local unit = Console.tagged_unit
	local dmg = unit and unit:character_damage()
	local bones = dmg._impact_bones
	
--	local bone = Console.tagged_calcium
--	local parent = Console.tagged_calcium_parent
	
	b = b or 0
	local i = 0
	if a == -1 then
		if unit.anim_state_machine and unit:anim_state_machine() then
			local machine = unit:anim_state_machine()
			machine:set_enabled(false)
		end
	elseif a == 0 then 
		Console.tagged_calcium = nil
		Console.tagged_calcium_parent = nil
		self:Log("Reset tagged bone + parent")
	elseif a == 1 then
		for _, bone_name in pairs(bones) do
			i = i + 1
			
			local bone_obj = unit:get_object(bone_name)
			self:Log(i .. ":" .. tostring(bone_name))
	--		local bone_dist_sq = mvector3.distance_sq(position, bone_obj:position())

	--		if not closest_bone or bone_dist_sq < closest_dist_sq then
	--			closest_bone = bone_obj
	--			closest_dist_sq = bone_dist_sq
	--		end
			if b == i then 
				Console.tagged_calcium = bone_obj
			end
		end
		self:Log("Selected bone " .. tostring(bone_name),{color = Color.yellow})
	elseif a == 2 then
		if Console.tagged_calcium then
			Console.tagged_calcium_parent = Console.tagged_calcium:parent()
--			Console.calcium_name = bone_name
			self:Log("Set tagged parent to " .. tostring(Console.tagged_calcium_parent),{color = Color.yellow})
		end
	elseif a == 3 then 
		if Console.tagged_calcium then
			self:Log("Attempted to move bone " .. tostring(Console.tagged_calcium),{color = Color.yellow})
			
			Console.tagged_calcium:set_position(Console.tagged_calcium:position() + Vector3(0,100,0))
		end
	elseif a == 4 then 
		if Console.tagged_calcium then 
			self:Log("Attempted to move parent bone " .. tostring(Console.tagged_calcium_parent),{color = Color.yellow})
			Console.tagged_calcium:set_position(Console.tagged_calcium_parent:position() + Vector3(0,100,0))
		end
	end
end
