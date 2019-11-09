--[[ TODO


* fix t_log not working for some reason
	do i gotta import kinetichud's version again?

**************** HIGH PRIORITY ****************
===============================================

- Fix failing to auto-newline scroll for new logs

- Fix only returning one value in a pair (output as {...}, read table)

- Fix postargs; should be max number of args instead

- Allow (i forgot what the rest of this sentence was meant to be)


===============================================

Mouse Control for scroll bar
Investigate viability of copying text/other mouse interactions with Console?

- Finish hitbox/hit proc visualization
(hit proc must hook to raycast in all likelihood)

- Timestamp in Console
	
Command "/bind":
	* blacklist ids of subcommands like:
		* help
		* /bind [key] or /bind [keyid] should return the bound action when no action argument is supplied

Command "/teleport":
	* optional "+" before value to do teleport jump relative to coordinates
		* eg. "/teleport +-500 300 -400" would move you back 500 units x, forward 300 units y, and -400 units z relative to your current position
	* optional single arg for teleporting n units forward in the direction of your aim
	* optional 3 args for rotlook
	

Persist Scripts:
	* Option to add by command string with InterpretInput(), as with "/tracker track"

Add optional HUD waypoint to position tagging, a la Goonmod Waypoints

Tracker:
	add var/cmd to recall value of tracked items for use in cmds

	make tracker more intuitive

Navigation
	- CTRL + (LEFTARROW/RIGHTARROW) to move cursor to next space/special char in left/right direction (spaces? periods? commas? todo figure that out)

- set debug for groupaistatebesiege

Settings
	- "Reset settings" button
	- Console window mover in mod options
	- Optionally, allow overriding log() function
		- Add console command "enablelogs" to enable/disable BLT logs or something


Debug HUD
	- wrap Debug HUD unit info in nice safe pcall() (whichever isn't already)
	- add more unit info 
	- add unit info /shortcommands to display info (accessible through chat)

- Import chat commands from OffyLib + allow chat in Offline Mode (disabled by default)
	
Keybinds functions:
	* Hold [modifier key] to select enemy and freeze AI
	- Select deployable at fwd_ray
	- Select misc object at fwd_ray




---extra features, for post release

Command Help
	- Add remaining syntax + usage + /help
	- Add command tooltips

- Instead of adding vspace by value, check against previous log's xy/wh values and add to those (also solves v whitespace issue)
	- Add remaining passed params to new_log_line()
	- Fix new_log_line() text height calculation (string.match count for "\n"?)
	- Move cmd history properly when sending new commands

- Scan for \n in strings, and replace with separate Log() line
	- Overflow to newline for character limits (should check against max length setting)
		- \n works for standard strings and hud text panels

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

/date can accept one of the following arguments: weekday (eg. result: Thursday), shortday (Thur), day (21), shortmonth (Sep), month (9), fullmonth (September), year (1978)
	without arguments, /date will output "MM/DD/YYYY"
/time can accept one of the following arguments: hour (eg. result: 1), minute (23), second (17),  us (04:20:00), i (04:20) (international 24-h),
	without arguments, /time will output "hh:mm:ss"
	
-----------------
v0.81 changes from last version:
- More thoroughly disabled input while Console is open
	- This still does not stop BLT keybinds from triggering
- Fixed crash on load when using saved keybinds from /bind 
- Fixed /quit crashing and generating a crashlog instead of nicely closing
- fixed broken persist/held setting for custom keybinds
- Console:logall() now has a global reference because I got tired of typing it all 
- Console:ClearConsole() is fixed and now works again + clears history properly so that the next logs are not still a million miles long
- Added `/clear` command which calls ClearConsole()
--]]

_G.Console = {}

Console.default_settings = {
	font_size = 12,
	margin = 2,
	scroll_speed = 12, --pixels per scroll action
	esc_behavior = 1,
	print_behavior = 1, --1 = default (do not modify behavior); 2 = tap (print() output to console, and also performs original print() ); 3 = overwrite (reroute to console); 4 = empty; print() executes no code (increases performance)
	keyboard_region = 1	--1 = us, 2 = uk
}
Console.settings = deep_clone(Console.default_settings)

function Console:ResetSettings()
	Console.settings = deep_clone(Console.default_settings)
	Console:Save()
end

Console.path = ModPath
Console.loc_path = Console.path .. "localization/"
Console.save_name = "command_prompt_settings.txt"
Console.save_path = SavePath .. Console.save_name
Console.options_name = "options.txt"
Console.options_path = Console.path .. "menu/" .. Console.options_name
Console.keybinds_name = "command_prompt_keybinds.txt" --custom keybinds; separate from BLT/mod keybinds
Console.keybinds_path = SavePath .. Console.keybinds_name
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
Console._restart_timer = false --used for /restart [timer] command: tracks next _restart_timer value to output (every second)
Console._restart_timer_t = false  --used for /restart [timer] command: tracks time left til 0 (restart)
Console._dt = 0 --should never be directly used for anything except calculation of dt itself
Console.selected_tracker = nil --string; holds id index of currently selected tracker from table _persist_trackers, NOT the element
Console.tagged_unit = nil --used for selected_unit for unit manipulation
Console.tagged_position = nil --used for waypoint/position manipulation
Console._failsafe = false --used for logall() debug function; probably should not be touched
--todo slap these in an init() function and call it at start
Console.show_debug_hud = false --off by default; enabled by keybind
Console.disable_achievements = true

Console.popups_count = 0
Console.popups = { --manage debug popups
}

function Console:Add_Popup(params)
	local panel = self._ws:panel()
	local name = tostring(params.name or self.popups_count)
	if self.popups[name] then 
		self:Log("ERROR: Add_Popup() [" .. name .. "] already exists!",{color = Color(0.5,1,0)}) --orange
		return
	end
	local parent = params.parent
	local position = params.position
	local lifetime = params.lifetime
	
	local result = {
		label = params.label,
		update = params.update,
		destroy = params.destroy,
		style = params.style,
		color = params.color,
		text = params.text,
		bitmap = params.bitmap
	}
	
	if parent and alive(parent) then 
		result.unit = parent
		result.position = position or parent:m_pos()
	elseif position then 
		result.position = position
		result.lifetime = params.lifetime or 5
	else 
		self:Log("ERROR: Add_Popup() No source or parent",{color = Color.red})
		return
	end

	if result.text then 
		if result.label then 
			result.text.text = result.label
		end
		result.text_element = panel:text(text)
	elseif result.label then 
		result.text_element = panel:text({
			name = "popup_" .. name,
			text = result.label,
			layer = 1,
--			align = "center",
			x = 0,
			y = 0,
			font = tweak_data.hud.medium_font,
			font_size = tweak_data.hud_players.name_size,
			color = result.color or Color.white
		})
	end
	
	if result.bitmap then	
		result.bitmap_element = panel:bitmap(result.bitmap)
	end
	
	self.popups_count = self.popups_count + 1
	self.popups[name] = result
end
function Console:Remove_Popup(name)
	local panel = self._ws:panel()
	local popup = self.popups[name] 
	if popup then 
		if alive(popup.text_element) then 
			panel:remove(popup.text_element)
		end
		if alive(popup.bitmap_element) then 
			panel:remove(popup.bitmap_element)
		end
		
		if popup.destroy then 
			popup.destroy(popup)
		end
		self.popups[name] = nil
	else
--		self:Log("ERROR: No popup [" .. name .. "]",{color = Color.red})
		return
	end
end
function Console:update_hud_popups(t,dt)
	if not self._ws then return end
	
	local panel = self._ws:panel()
	for k,v in pairs(self.popups) do 
		
		local pos = nil
		if v.position and type(v.position) == "Vector3" then 
			pos = v.position
		elseif (v.unit ~= nil) and alive(v.unit) then 
			pos = v.unit:m_pos()
			if v.position == "head" then 
				pos = v.unit:movement():m_head_pos()
			end
		end
		if pos then 
			local hud_pos = (self._ws:world_to_screen(managers.viewport:get_current_camera(),pos)) or {}
			local _,_,text_w,_ = v.text_element:text_rect()
			v.text_element:set_x((hud_pos.x or 0) - (text_w / 2))
			v.text_element:set_y(hud_pos.y or 0)
			if v.bitmap_element then 
				v.bitmap_element:set_x(hud_pos.x or 0)
				v.bitmap_element:set_y(hud_pos.y or 0)
			end
			
		end
		if v.update then
			v.update(t,dt,v)
		end
	end
end

Console.command_history = {
--	[1] = { name = "/say thing", func = (function value) } --as an example
}

Console.color_data = { --for ui stuff
	scroll_handle = Color(0.1,0.3,0.7),
	chat_color = Color("8650AC"),
	debug_brush_tagged_enemy = Color.yellow:with_alpha(0.1),
	debug_brush_enemies = Color.red:with_alpha(0.1),
	debug_brush_world = Color.green:with_alpha(0.1),
	result_color = Color(0.1,0.5,1),
	fail_color = Color(1,0,0)
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

Console._tagunit_brush = Draw:brush(Console.color_data.debug_brush_enemies) --arg2 is lifetime; since this updates every frame, should be nil
Console._tagworld_brush = Draw:brush(Console.color_data.debug_brush_world)

--todo /kick, /ban
Console.command_list = { --in string form so that they can be called with loadstring() and run safely in a pcall; --todo update
	help = {
		str = "Console:cmd_help($ARGS)",
		desc = "Get information about a command, or list all commands.",
		postargs = 1, --denotes number of args before semicolon spacer is required; should only be used to force first argument to be single-word
		max_args = 1 --NOT IMPLEMENTED- if no semicolon, arguments at or after this number will be concatenated into one single argument
	},	
	about = {
		str = "Console:cmd_about()", 
		desc = "Outputs basic mod info about Console.",
		postargs = 0
	},
	contact = {
		str = "Console:cmd_contact()",
		desc = "Outputs the mod author's contact info.",
		postargs = 0
	},
	info = {
		str = "Console:cmd_info($ARGS)",
		desc = "Not implemented.",
		postargs = 0
	},
	ping = {
		str = "Console:cmd_ping($ARGS)",
		desc = "Outputs latency (in milliseconds) to a player.",
		postargs = 0
	},
	say = {
		str = "Console:cmd_say($ARGS)",
		desc =  "Outputs message to chat as one would chat normally.",
		postargs = 0
	},
	whisper = {
		str = "Console:cmd_whisper($ARGS)", --outputs private message to user
		desc = "Sends a private message to the user of your choice.",
		postargs = 0
	},
	tracker = {
		str = "Console:cmd_tracker($ARGS)",
		desc = "Various subcommands related to tracking variables and displaying their contents to the HUD.",
		postargs = 0
	},
	god = {
		str = "Console:cmd_godmode($ARGS)",
		desc = "Sorry, kids, you don't get the kool cheats unless you're me",
		postargs = 0,
		hidden = true
	},
	exec = {
		str = "Console:cmd_dofile($ARGS)",
		desc = "dofile(). Literally just dofile()",
		postargs = 0
	},
	["dofile"] = {		--don't you give me your syntax-highlighting sass, np++, i know dofile is already a thing
		str = "Console:cmd_dofile($ARGS)",
		desc = "Sorry, just dofile() again.",
		postargs = 0
	},
	teleport = {
		str = "Console:cmd_teleport($ARGS)",
		desc = "Moves you to the location of your choice. Can be a waypoint or a manually input location.",
		postargs = 0
	},
	clear = {
		str = "Console:ClearConsole()",
		desc = "Clears the console window's recent commands and results.",
		postargs = 0
	},
	pos = {
		str = "Console:cmd_pos($ARGS)",
		desc = "Prints the player's world position to the console window. Optional: Specify peer_id of target player.",
		postargs = 0
	},
	tp = {
		str = "Console:cmd_teleport($ARGS)",
		desc = "Moves you to the location of your choice. Can be a waypoint or a manually input location.",
		postargs = 0
	},
	bind = {
		str = "Console:cmd_bind($ARGS)", --is this tf2.jpg
		desc = "Binds a key to execute a function or command.",
		postargs = 0
	},
	bindid = {
		str = "Console:cmd_bindid($ARGS)",
		desc = "Hooks an existing BLT keybind to execute a function or command.",
		postargs = 0
	},
	unbind = {
		str = "Console:cmd_unbind($ARGS)", --i hear unbindall in console gives you infinite ammo :^)
		desc = "Unbinds the existing key or hooked BLT keybind. (Does not interfere with normal keybind function.)",
		postargs = 0
	},
	unbindall = {
		str = "Console:cmd_unbindall()",
		desc = "Unbinds all keys and hooked BLT keybinds.",
		postargs = 0
	},
	["time"] = {
		str = "Console:cmd_time($ARGS)",
		desc = "Shows the current system time, formatted.",
		postargs = 0
	},
	epoch = {
		str = "Console:cmd_epoch($ARGS)",
		desc = "Displays the current time in seconds after epoch.",
		postargs = 0
	},
	["date"] = {
		str = "Console:cmd_date($ARGS)", 
		desc = "Outputs system date to console.",
		postargs = 0
	},
	pause = {
		str = "Console:cmd_pause($ARGS)",
		desc = "In offline mode, pauses the game. In multiplayer, sets game speed to very, very, very slow.",
		postargs = 0
	},
	quit = {
		str = "Console:cmd_quit($ARGS)", 
		desc = "Closes PAYDAY 2 executable (after a confirm prompt).",
		postargs = 1
	},
	restart = {
		str = "Console:cmd_restart($ARGS)",
		desc = "Restarts heist day; argument is seconds delay to restart",
		postargs = 1
	},
	savetable = {
		str = "Console:cmd_writetodisk($ARGS)", -- [data] [pathname]
		desc = "Writes a table to the disk.",
		postargs = 0
	},
	stop = {
		str = "Console:cmd_stop($ARGS)",
		desc = "Stops existing persist scripts, or any current logall() process.",
		postargs = 0
	},
	adventure = {
		str = "Console:cmd_adventure($ARGS)",
		desc = "",
		postargs = 1,
		hidden = true
	}
}

Console.h_margin = 24
Console.v_margin = 3

Console._keybind_cache = { --whether the key is currently being held (or was last frame)
--	[keybind_id_1] = true,
--	[keybind_Id_2] = false
}
Console._custom_keybinds = {
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

function Console:cmd_godmode(...)
--just make your own cheats jeez
	if OffyLib then 
		OffyLib:EnableInvuln(...)
	else
		self:Log("That command is disabled!",{color = self.quality_colors.strange})
	end
end

function Console:RegisterCommand(id,data)
	if not id then
		self:Log("ERROR: RegisterCommand(" .. tostring(id)..") failed: Bad command name",{color = Color.red}) 
		return
	elseif (type(data) ~= "table") or not data.str then 
		self:Log("ERROR: RegisterCommand(" .. tostring(id)..") failed: Bad command data",{color = Color.red}) 
		return
	end
	self.command_list[id] = {
		str = data.str or "",
		desc = data.desc,
		postargs = data.postargs,
		hidden = data.hidden
	}
end

Hooks:Add("PlayerManager_on_internal_load","console_oninternalload",function()  --called on event PlayerManager:_internal_load()
--since console should work in all environments (main menu, beardlib editor environments, and in-game), this event hook should be phased out

	--load keybinds
	--do stuff for Console development here such as creating tracker elements
	Console:refresh_scroll_handle()
	local tracker_a = Console:CreateTracker("trackera")
	local tracker_b = Console:CreateTracker("trackerb")
	local tracker_c = Console:CreateTracker("trackerc")
	local tracker_d = Console:CreateTracker("trackerd")
	local tracker_e = Console:CreateTracker("trackere")
	tracker_a:set_x(200)
	tracker_a:set_y(250)
	tracker_b:set_x(200)
	tracker_b:set_y(300)
	tracker_c:set_x(200)
	tracker_c:set_y(350)
	tracker_d:set_x(200)
	tracker_d:set_y(400)
	tracker_e:set_x(200)
	tracker_e:set_y(450)
	--[[
	local function d ()
		local held = HoldTheKey:Key_Held("a")
		local tracker = Console:GetTrackerElementByName("trackera")
		Console:SetTrackerValue("trackera",tostring(held))
	end
	
	self:RegisterPersistScript("trackera_persist",d)
	--]]
end)

function Console:GetEscBehavior()
	return self.settings.esc_behavior
end

function Console:GetKeyboardRegion()
	local region_key = {
		[1] = "us",
		[2] = "uk"
	}
	local region = self.settings.keyboard_region or 1
	return region_key[region] or "us"
end

function Console:GetFontSize()
	return self.settings.font_size
end

function Console:GetScrollSpeed()
	return self.settings.scroll_speed
end

function Console:GetPrintMode()
	return self.settings.print_behavior
end

function Console:SaveKeybinds()
	local file = io.open(self.keybinds_path,"w+")
	if file then
		file:write(json.encode(self._custom_keybinds))
		file:close()
	end
end

function Console:LoadKeybinds()
--read bind info and manually bind: do not use cmd_bind() since it would call SaveKeybinds()
	local file = io.open(self.keybinds_path, "r")
	if (file) then
		for keybind_id, data in pairs(json.decode(file:read("*all"))) do
			if data then 
				local func_str = data.func_str
				if not func_str then 
					self:Log("ERROR: NO FUNC STR",{color = Color.red})
				end
				local k_category = data.k_category or "key_name"
				local persist = data.persist
				local func,new_func_str = self:InterpretInput(func_str)
				if (func and func_str) then 
					self._custom_keybinds[keybind_id] = { --overwrite existing entirely, unlike /bind
						persist = persist,
						func = func,
						func_str = func_str,
						category = k_category,
					}
					self:Log("Restoring saved keybinds: Bound " .. keybind_id .. " to " .. func_str,{color = self.quality_colors.unique})
				else
					local cat = data.k_category or "[nil bind type]"
					self:Log("Could not read saved " .. cat .. " : " .. tostring(keybind_id),{color = Color.red})			
				end
			else
				self:Log("Bad data for saved keybind: " .. keybind_id,{color = Color.red})
			end
		end
	else
		self:SaveKeybinds()
	end
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

Console:Load()

local orig_print = _G.print
local __print_behavior = Console:GetPrintMode()
if __print_behavior == 1 then
	--please do nothing to the cook
elseif __print_behavior == 2 then 

	--output to both console and BLT log window (or other, if you have (or another mod has) changed print() for your/its own purposes)
		function _G.print(...) 
			local result = "print( "
			for k,item in pairs({...}) do
				result = result .. tostring(item) .. " "
			end
			result = result .. ")"
			Console:Log(result,{color = Console.quality_colors.rare})
			orig_print(...)
		end
		
elseif __print_behavior == 3 then 
	
	--only output to console
		function _G.print(...) 
			local result = "print( "
			for k,item in pairs({...}) do
				result = result .. tostring(item) .. " "
			end
			result = result .. ")"
			Console:Log(result,{color = Console.quality_colors.rare})
		end
		
elseif __print_behavior == 4 then

	function _G.print()
		--do nothing; probably increases performance somewhat
	end
	
end
	
function _G.Log(...)
	Console:Log(...)
end

function _G.logall(obj,max_amount)
--generally best used to log all of the properties of a Class:
--functions;
--and values, such as numbers, strings, tables, etc.
	local type_colors = {
		["function"] = Color(0.5,1,1),
		["string"] = Color(0.5,0.5,0.5),
		["number"] = Color(0.66,1,0),
		["Vector3"] = Color(1,0.5,1),
		["Rotation"] = Color(0.7,0.5,1),
		["Panel"] = Color(0.5,0.6,1),
		["Bitmap"] = Color(0.3,1,0.7),
		["Color"] = Color(1,0.7,0.7),
		["Unit"] = Color(1,1,0.3),
		["table"] = Color(1,1,0),
		["userdata"] = Color(1,0,0)
	}
	
	if not obj then 
		Console:Log("Nil obj to argument1 [" .. tostring(obj) .. "]",{color = Color.red})
		return
	end
	local i = max_amount and 0
	Console._failsafe = false
	while not Console._failsafe do 
		if i then 
			i = i + 1
			if i > max_amount then
				Console:Log("Reached manual log limit " .. tostring(max_amount),{color = Color.yellow})
				return
			end
		end
		for k,v in pairs(obj) do 
			local data_type = type(v)
			if data_type == "userdata" then 
				for i,j in pairs(type_colors) do 
					if _G[i] and _G[i].type_id == v.type_id then 
						data_type = i
						break
					end
				end
			end
			
			Console:Log("Index [" .. tostring(k) .. "] : [" .. tostring(v) .. "]",{color = type_colors[data_type]})
		end
		Console._failsafe = true --process can be stopped with "/stop" if log turns out to be recursive or too long in general
	end
end

function Console:logall(...)
	return logall(...)
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
	if not panel then 
		--Console is not fully init yet
		return
	end
	local frame = panel:child("command_history_frame")
	local history = frame:child("command_history_panel")
		
	local line
	local v_margin = self.v_margin
	local h_margin = params.h_margin or self.h_margin
	history:set_h(history:h() + font_size)
	history:child("history_size_debug"):set_h(history:h())
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

--	history:set_y(history:y() + scroll_speed,0)
	return line
end

function Console:angle_between_pos(a,b,c,d)
	a = a or "nil"
	b = b or "nil"
	c = c or "nil"
	d = d or "nil"
	local vectype = type(Vector3())
	local function do_angle(x1,y1,x2,y2)
		local angle = 0
		local x = x2 - x1 --x diff
		local y = y2 - y1 --y diff
		if x ~= 0 then 
			angle = math.atan(y / x) % 180
			if y == 0 then 
				if x > 0 then 
					angle = 180 --right
				else
					angle = 0 --left 
				end
			elseif y > 0 then 
				angle = angle - 180
			end
		else
			if y > 0 then
				angle = 270 --up
			else
				angle = 90 --down
			end
		end
		
		return angle
	end
	if (type(a) == vectype) and (type(b) == vectype) then  --vector pos diff
		return do_angle(a.x,a.y,b.x,b.y)
	elseif (type(a) == "number") and (type(b) == "number") and (type(c) == "number") and (type(d) == "number") then --manual x/y pos diff
		return do_angle(a,b,c,d)
	else
		self:Log("ERROR: angle_between_pos(" .. table.concat({a,b,c,d},",") .. ") failed - bad/mismatched arg types")
		return
	end
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

function Console:t_log(tbl,name,tier_limit,result,tier,return_result)
	local space = "      " --6 spaces
--[[
	local col
	local col_data = self.quality_colors
	local col_tbl = {
		col_data.normal,
		col_data.common,
		col_data.rare,
		col_data.unusual,
		col_data.exotic
	}
	--]]
	name = name or ("TABLE " .. (tier or ""))
	tier = tier or 1
	tier_limit = tier_limit or 10
	result = result or {
		tostring(name) .. " = {"
	}
	if tier > tier_limit then 
		return
	end
	if type(tbl) == "table" then 
		for k,v in pairs(tbl) do
			if type(v) == "table" then 
				table.insert(result,string.rep(space,tier) .. tostring(k) .. " = {")
				result = self:t_log(v,k,tier_limit,result,tier + 1,true)
				table.insert(result,string.rep(space,tier) .. "}")
			else
				table.insert(result,string.rep(space,tier) .. tostring(k) .. " = { " .. tostring(v) .. " }")
			end
		end
--		return result
	else
		table.insert(result,string.rep(space,tier + 1) .. tostring(tbl))
		table.insert(result,string.rep(space,tier) .. "}")
	end
	if return_result then 
		return result
	end
	table.insert(result,"}")
	for _,line in pairs(result) do
--Console:t_log({rwby = {r = "ruby",w = "weiss",b = "blake",y = "yang",{cfvy = {c = "coco",f = "fox",v = "velvet",y = "yatsuhashi"}},tacobell = {delicious = true,healthy = false,cost = 11.95,favorite = "dorito"}}},"waifus")		
		self:Log("| " .. tostring(line),{color = self.quality_colors.solar})
	end
	
	
end

function Console:t_log_2(input_tbl,label,max_tiers)
	max_tiers = max_tiers or -1 
	--if max_tiers == -1, infinite potential log depth. 
	--can be stopped with /stop in case of infinite recursion
	local col_data = self.quality_colors
	local col_tbl = {
		col_data.normal,
		col_data.common,
		col_data.rare,
		col_data.unusual,
		col_data.exotic		
	}

	local function tlog(tbl,tiers) 
		local tier_current
		if self._failsafe then 
			return --manually ended prematurely
		end
		for k,v in pairs(tbl) do 
			local whitespace = string.rep("    ",tiers)
			if type(v) == "table" then
				if (tiers <= max_tiers) or (max_tiers == -1) then 
					self:Log(whitespace .. tostring(k) .. " = {",{color = col})
					tlog(v,tiers + 1)
				else
					self:Log(whitespace .. "}",{color = col})
				end
			else
				local col = col_tbl[(tiers % #col_tbl) + 1]
				self:Log(whitespace .. tostring(k) .. " = " .. tostring(v),{color = col})
			end
		end
	end

	if not (input_tbl and type(input_tbl) == "table") then 
		self:Log("ERROR: Console:t_log(" .. tostring(input_tbl) .. "," .. tostring(label) .. "): arg1 is not a table!",{color = Color.yellow})
		return
	else
		self:Log("Logging '" .. tostring(label) .. "'")
		
		tlog(input_tbl,0)
		self._failsafe = true
		self:Log("Ended log '" .. tostring(label) .. "'")
	end
	
end

function Console:cmd_tracker(subcmd,id,...) --interpret
--[[
	self:Log("SUBCMD:" .. tostring(subcmd) .. ",ID=" .. tostring(ID),{color = Color.yellow})
	local a = {...}
	if a and #a > 0 then 
		self:t_log(a,"...?")
	end
	--]]
	
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

function Console:cmd_unit(subcmd,id,...) --not implemented
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

function Console:AdventureInput(str) --unused
	Console.__adventure:ReceiveInput(str)
end

function Console:cmd_adventure(toggle) --unused
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

function Console:cmd_unbind(key_name)
	key_name = key_name and tostring(key_name)
	if key_name then 
		if self._custom_keybinds[key_name] then
			self._custom_keybinds[key_name] = nil
		end
	end
	self:SaveKeybinds()
end

function Console:cmd_unbindall()
	self._custom_keybinds = {}
	--[[
	for id,keybind_data in pairs(self._custom_keybinds) do 
		keybind_data = nil
	end--]]
	--save data?
	self:SaveKeybinds()
end

function Console:cmd_bind(key_name,input_str,held,...) --func is actually a string which is fed into Console's command interpreter
	if (key_name == "help") then
		self:Log("Syntax: /bindid [string: key_name] [function to execute; or string to parse] [optional bool: held]",{color = Color.yellow})
		self:Log("Usage: Bind a key to execute a Lua snippet or Console command.",{color = Color.yellow})
		self:Log("Example: /bind a Console:Log(\"I just pressed (a)!\")",{color = Color.yellow})
		return
	elseif (key_name == "list") then 
		self:Log("List of bound keybinds:")
		for id,keybind_data in pairs(self._custom_keybinds) do 
			local k_category = keybind_data.k_category or "key_name"
			self:Log(((k_category == "key_name" and "key ") or "BLT ") .. id .. " : " .. keybind_data.func_str)
		end
		return
	else
		local err = false
		if (not key_name) or (key_name == "") then 
			self:Log("Error: You must supply a key to bind!",{color = Color.red})
			err = true
		end
		if not input_str then 
			self:Log("Error: You must supply a command, code, or function to execute!",{color = Color.red})
			err = true
		end
		-- show non-exclusive error messages
		if err then 
			return
		end
	end
	self:Log("Bound " .. key_name,{color = Color.blue})
	--[[
	if key_name then 
		local func,func_str = self:InterpretInput(input_str)

		if func then 
			if self._custom_keybinds[key_name] then --if nil or invalid func parameter then show current bind
				self:Log(tostring(key_name) .. " is already bound to [" .. self._custom_keybinds[key_name].func_str .. "]!",{color = Color.yellow})
				self:Log("Rebinding " .. tostring(key_name) .. " to [" .. tostring(input_str) .. "]",{color = Color.yellow})
				self._custom_keybinds[key_name].func = func
				self._custom_keybinds[key_name].func_str = func_str
				return
			else
				self._custom_keybinds[key_name] = {
					persist = held or false,
					func = func,
					func_str = func_str,
					category = "key_name"
				}
				self:Log("Bound " .. tostring(key_name) .. " to [" .. tostring(func_str) .. "]",{color = Color.yellow})
			end
		else
			--send error
		end
	end
	--]]
	self:AddBind("key_name",key_name,input_str,held)
end

function Console:AddBind(category,id,input_str,held) --todo
	input_str = input_str and tostring(input_str)
	if not input_str then 
		self:Log("ERROR: AddBind(): You must supply a command, code, or function to execute!",{color = Color.red})
		return
	end
	local func, func_str = self:InterpretInput(input_str) --loadstring and parsing
	if not func then
		self:Log("ERROR: Invalid func_str to " .. (category == "key_name" and "/bind" or "/bindid"),{color = Color.red})
		return 
	end
	if self._custom_keybinds[id] then --overwrite bind
		self:Log(tostring(id) .. " is already bound to [" .. self._custom_keybinds[id].func_str .. "]!",{color = Color.yellow})
		self:Log("Rebinding " .. tostring(id) .. " to [" .. tostring(func_str) .. "]",{color = Color.yellow})
		self._custom_keybinds[id].func = func
		self._custom_keybinds[id].func_str = func_str
		self._custom_keybinds[id].category = category --not my problem if someone decides to name their BLT mod's keybind id to "a", i roll with the punches
	else	
		self._custom_keybinds[id] = {
			func = func, --function to execute
			persist = held,
			func_str = func_str, --input: this can be a /command or a lua snippet (parsed automatically by InterpretInput() )
			category = category --"key_name" or "bind_id"
		}
		self:Log("Bound " .. tostring(id) .. " to [" .. tostring(func_str) .. "]",{color = Color.yellow})
	end
	self:SaveKeybinds()
end

function Console:cmd_bindid(keybind_id,input_str,held,...)
--todo popup box req HoldTheKey
	if (keybind_id == "help") then 
		self:Log("Syntax: /bind [string: keybind_id] [function to execute; or string to parse] [optional bool: held]",{color = Color.yellow})
		self:Log("Usage: Bind a key to execute a Lua snippet or Console commmand.",{color = Color.yellow})
		self:Log("Example: /bindid keybindid_taclean_left Console:Log(\"I just pressed (keybindid_taclean_left)!\")",{color = Color.yellow})
		return
	elseif (keybind_id == "list") then 
		self:Log("List of bound keybinds:")
		for id,keybind_data in pairs(self._custom_keybinds) do 
			local k_category = keybind_data.k_category or "key_name"
			self:Log(((k_category == "key_name" and "key ") or "BLT ") .. id .. " : " .. keybind_data.func_str)
		end
		return
	else
		if (not keybind_id) or (keybind_id == "") then 
			self:Log("Error: You must supply a BLT keybind_id to bind!",{color = Color.red})
		end
		if not input_str then 
			self:Log("Error: You must supply a command, code, or function to execute!",{color = Color.red})
		end
		return
	end
--[[
	if keybind_id then --todo check blt.keybinds for valid keybind registration
		local func, func_str = self:InterpretInput(func_str)
		if self._custom_keybinds[keybind_id] then
			self:Log(tostring(key_name) .. " is already bound to [" .. self._custom_keybinds[key_name].func_str .. "]!",{color = Color.yellow})	
			return self._custom_keybinds[keybind_id]
		elseif not func then
			self:Log("Error: You must supply a command, code, or function to execute!")
			return
		elseif func then 
			self._custom_keybinds[keybind_id] = {
				persist = held or false,
				func = func,
				func_str = func_str,
				category = "bind_id"
			}
		end
	end
--]]
	self:AddBind("bind_id",keybind_id,input_str,held)
end

function Console:cmd_help(cmd_name)
	if cmd_name and self.command_list[cmd_name] then -- and string.find(self.command_list[cmd_name].str,"$ARGS") then 
--		self:Log("Try '/" .. cmd_name .. " help'.",{color = Color.yellow}) 
		self:Log(tostring(self.command_list[cmd_name].desc),{color = Color.yellow})
	else
		self:Log("Available commands:",{color = Color.green})
		for name,data in pairs(self.command_list) do 
			if not data.hidden then 
				self:Log(name)
			end
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

function Console:cmd_epoch(custom_format)
	self:Log(os.time(custom_format),{color = Color.yellow})
end

function Console:cmd_runtime()
	self:Log(os.clock(),{color = Color.yellow})
end

function Console:cmd_time(custom_format)
	local options = {
		hour = "%I",
		hours = "%I",
		us = "%H",
		minute = "%M",
		minutes = "%M",
		["min"] = "%M",
		h = "%I",
	}
	custom_format = (custom_format and options[custom_format]) or custom_format or "%X"
	self:Log(os.date(custom_format),{color = Color.yellow})
end

function Console:cmd_date(custom_format)
	local options = {
		weekday = "%A",
		shortday = "%a",
		day = "%d",
		shortmonth = "%b",
		month = "%m",
		fullmonth = "%B",
		year = "%Y",
		shortyear = "%y"
	}

	custom_format = (custom_format and options[custom_format]) or custom_format or "%x"
	self:Log(os.date(custom_format),{color = Color.yellow})
--	self:Log(tostring(os.date()))
end

function Console:cmd_whisper(target,message)
	if target == "help" then 
		self:Log("Syntax: /whisper [peer_id (1-4)] [message]",{color = Color.yellow})
		self:Log("Usage: Send a private message to a single player without other players reading it.",{color = Color.yellow})
		return
	end
	target = tonumber(target)
	if not target then	
		self:Log("ERROR: /whisper: argument#1 must be a number 1-4")
		return
	end --log error
	if managers.network:session() and managers.chat and managers.network:session():peers() then
		local channel = managers.chat._channel_id or 1
		local msg_str
		for peer_id, peer in pairs( managers.network:session():peers() ) do
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
	if not message then 
		self:Log("ERROR: /say: You must include a message!")
		return
	end
	if managers.chat then 
		local channel = managers.chat._channel_id or tonumber(ChatManager.GAME) or 1
		local sender_name = (managers.network and managers.network.account:username()) or "Someone"
		managers.chat:send_message(channel, sender_name, message)
--		managers.chat:_receive_message(channel,sender_name,message,tweak_data.chat_colors[managers.network:session():local_peer():id()])
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
--		Application:quit() and Setup:quit() do nothing (unless you have The Fixes, in which case Setup:quit() does stuff
--		os.execute('taskkill /IM "payday2_win32_release.exe" /F') --this also works
		MenuCallbackHandler:_dialog_quit_yes()
		return
	end
	MenuCallbackHandler:quit_game()
end

function Console:cmd_pos(peer_id)
	local player = managers.player:player_unit(peer_id)
	if not alive(player) then 
		self:Log("ERROR: /pos: Player unit is not alive")
		return
	end
	
	self:Log(player:movement():m_pos())
end

function Console:cmd_rot(peer_id)
	local player = managers.player:player_unit()
	if not alive(player) then 
		self:Log("ERROR: /rot: Player unit is not alive")
		return
	end
	return player:camera():rotation()
end

function Console:cmd_teleport(x,y,z,camx,camy)
	self.disable_achievements = true
	local player = managers.player:local_player()
	if not alive(player) then 
		self:Log("Can't teleport if you're dead!",{color = Color.red})
		return
	end
	local camera = player:camera()
	local pos
	if x and type(x) == "string" then 
		if x == "aim" then
			pos = Console:GetTaggedPosition()
		end
	end
	
	if not (x and y and z) then --teleport to aim if no arguments supplied
		if x and not (y or z) then --assume x is 
			pos = mvector3.copy(player:movement():m_pos())
			local rot = mvector3.copy(camera:rotation():y())
			mvector3.multiply(rot,x)
			mvector3.add(pos,rot)
--			Log("Teleporting a distance of " .. tostring(rot) .. " from " .. tostring(player:movement():m_pos()) .. " (Moved " .. tostring(x) .. " units across attitude " .. tostring(rot) .. ")")
--			Log(player:movement():m_pos() .. " + " .. tostring(rot) .. " = " .. tostring(rot + player:movement():m_pos()))
		else
			pos = Console:GetTaggedPosition()
		end
--			pos = pos or Console:GetFwdRay().position
	end
	pos = pos or Vector3(tonumber(x or 0), tonumber(y or 0), tonumber(z or 0))
	camx = tonumber(camx or player:rotation():yaw()) or player:rotation():yaw()
	camy = tonumber(camy or player:rotation():pitch()) or player:rotation():pitch()
	if player and pos then
		managers.player:warp_to(pos,Rotation(camx,camy,0))
	end
end

function Console:cmd_pause(active)
	if Global.game_settings.single_player then
		if active then
			Application:set_pause(true)
			managers.menu:post_event("game_pause_in_game_menu")
			SoundDevice:set_rtpc("ingame_sound", 0)

			local player_unit = managers.player:player_unit()

			if alive(player_unit) and player_unit:movement():current_state().update_check_actions_paused then
				player_unit:movement():current_state():update_check_actions_paused()
			end
		else
			Application:set_pause(false)
			managers.menu:post_event("game_resume")
			SoundDevice:set_rtpc("ingame_sound", 1)
		end
	else
		
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

function Console:cmd_ping(peerid)
	peerid = tonumber(peerid)
	
	local ping = -1
	local _peer = peerid and managers.network:session() and managers.network:session():peer(peerid)
	if peerid then 
		if not _peer then 
			self:Log("Invalid peer: " .. tostring(peerid),{color = self.quality_colors.strange})
			return
		end
		
		ping = _peer:qos().ping
		self:Log(tostring(peerid) .. ": " .. tostring(ping) .. " ms",{color = tweak_data.chat_colors[peerid]})
	else
		
		for i = 1, 4 do --id,peer in pairs() do
			local peer = managers.network:session() and managers.network:session():peer(i)
			ping = (peer and peer:qos().ping)
			ping = (ping and (ping .. " ms")) or "-"
			self:Log(tostring(i) .. ": " .. tostring(ping),{color = tweak_data.chat_colors[i]})
		end
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

function Console:ClearConsole()
	local history = self._panel:child("command_history_frame"):child("command_history_panel")
	for i=1,self.num_lines,1 do 
		local line = history:child("history_cmd_" .. tostring(i))
		if line and alive(line) then 
			history:remove(line)
		end
	end
	history:set_h(self:GetFontSize())
	self.num_commands = 1
	self.num_lines = 1
	self.command_history = {}
end

function Console:held(key)
	if HoldTheKey then
		return HoldTheKey:Key_Held(key)
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

function Console:mouse_moved(o,x,y)
--	self:SetTrackerValue("tracker_a",tostring(x) .. "," .. tostring(y))
--	self:Log("Mousemoved " .. tostring(x) .. "," .. tostring(y))
	if true then return end
	
	if not self._panel:inside(x,y) then 
		return 
	end
	
	
	
	
end

function Console:mouse_clicked(o,button,x,y)
--	self:Log("Mouseclicked")
	if true then return end
	
	if button ~= Idstring("0") or not self._panel:inside(x,y) then 
		return
	end
	
	
	
end

function Console:ToggleConsoleFocus(focused)
	if not alive(self._panel) then 
		log("Console:ToggleConsoleFocus() ERROR: Attempted to open console window, but Console window does not exist")
		return
	end
	
	if (focused == true) or (focused == false) then 
		self._focus = focused
	else
		self._focus = not self._focus
	end
	self._panel:set_visible(self._focus)

	if self._focus then 
	
		if managers.menu and managers.menu:active_menu() and managers.menu:active_menu().renderer then 
			managers.menu:active_menu().renderer:disable_input(math.huge)
		end
		
		local data = {
			mouse_move = callback(self, self, "mouse_moved"),
			mouse_click = callback(self, self, "mouse_clicked"),
			id = "console_test_mousepointer"
		}
		
		game_state_machine:_set_controller_enabled(false);
		managers.mouse_pointer:use_mouse(data);	
	
		self._enter_text_set = false
		self._ws:connect_keyboard(Input:keyboard())

		self._enabled = true
	
		self._panel:child("input_text"):key_press(callback(self, self, "key_press"))
		self._panel:child("input_text"):key_release(callback(self, self, "key_release"))

	else
		if managers.menu and managers.menu:active_menu() and managers.menu:active_menu().renderer then 
			managers.menu:active_menu().renderer:disable_input(0.1)
		end

		
		self._ws:disconnect_keyboard()
		self._panel:key_release(nil)
		managers.mouse_pointer:remove_mouse("console_test_mousepointer")	
		game_state_machine:_set_controller_enabled(true)
		self._enabled = false
	end
	
	--self:cmd_pause(self._focus)
	
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
		Console:Remove_Popup("selected")
		Console:Add_Popup({name = "selected",parent = unit,position = "head",lifetime = nil,color = Color.yellow,label = unit:base()._tweak_table})
	else
		Console:Remove_Popup("selected")
		self.tagged_unit = nil
	end
end

function Console:GetTaggedPosition()
	return self.tagged_position
end

function Console:GetTaggedUnit()
	return self.tagged_unit
end

function Console:AchievementsDisabled()
	return self.disable_achievements and not self.settings.dev
end

function Console:GetCharList()
	--local region = System:region() or "US" or whatever i guess
	local region = self:GetKeyboardRegion()
	if not self._console_charlist then 
		self._console_charlist = self:BuildCharList(region)
	end
	return self._console_charlist
end

function Console:BuildCharList(region) --i'm either a genius or an idiot, depends on who you talk to
	local characters = {
		us = {
			alpha = { ["abcdefghijklmnopqrstuvwxyz"] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"},
			numeric = {["1234567890"] = "!@#$%^&*()"},
			symbol = {["-=[]\\;,./\'"] = "_+{}|:<>?\""}
	--		tilde = {["`"] = "~"}, --this gets its own conditional in update_key_press()
		},
		uk = {
			alpha = { ["abcdefghijklmnopqrstuvwxyz"] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"},
			numeric = { ["14567890"] = "!$%^&*()"},
			symbol = { ["-=[];#,./"] = "_+{}:~<>?"},
			special = { ["2\'"] = '\"@' }, -- 2 = ", ' = @
			helpmeiaminhell = { ["3"] = "L"}--"₤" }--string.char(194) } --yeah that doesn't work. why.
		}
	}

	local raw = characters[region] or characters.us
	
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
	
	local panel = self._panel
	local input_text = panel:child("input_text")
	
	local cmd_raw = input_text:text()
	if cmd_raw == "" then 
		--empty command; do nothing
		return
	end
	input_text:set_text("")
	
	if self._adventure then
		self:AdventureInput(cmd_raw)
		return
	end
	
	local success,result
	local func,cmd = self:InterpretInput(cmd_raw) 
	
	if func then 
		success,result = pcall(func)
	else
--		self:Log("Execution failed.",{color = Color.red})
--		return
	end
	
	if success then 
		if result ~= nil then
			self:Log(result,{color = self.color_data.result_color})
		else
			self:Log("Done",{color = Color.yellow})
		end
	else
		self:Log("Command execution failed")
	end
	table.insert(self.command_history,{name = cmd or cmd_raw,func = func})
	self:refresh_scroll_handle()
end

function Console:split_two(str,postargs)
	local skip_semi = false
	postargs = postargs or 0
	local args = {}

	if not string.find(str,";") then skip_semi = true end
	local pair = {}
	local first = 1
	local last
	for i = 1, string.len(str),1 do --split by ";"
		local this_char = string.sub(str,i,i)
		if (postargs > 0) or (skip_semi) then
			if i == string.len(str) then
				if first then 
					table.insert(args,string.sub(str,first,i))
					if not skip_semi then
						postargs = postargs - 1
					end
					first = nil
				end
			elseif (this_char == " ") then 
				if first then 
					
					last = i - 1
					table.insert(args,string.sub(str,first,last))
					first = i + 1
					if not skip_semi then
						postargs = postargs - 1	
					end
					if postargs <= 0 and not skip_semi then 
						first = i + 1
					end
					last = nil
				else
					first = i + 1
				end
			end
		else
			if i == string.len(str) then 
				if first then 
					if this_char == ";" then 
						last = i - 1
					else
						last = i
					end
					table.insert(args,string.sub(str,first,last))
				end
			elseif this_char == ";" then 
				if first then 
					last = i - 1
					table.insert(args,string.sub(str,first,last))
					first = i + 1
					last = nil
				else
					first = i + 1
				end
			elseif this_char == " " then 
				if first then
					if first == i then 
						first = i + 1
					end
				end
			end
		end
	end
	return args
end

function Console:split_cmd(str)
	if not (str and string.len(str) >= 1) then
		self:Log("No str provided",{color = Color.red})
		return
	end
	local result
	for i=1, string.len(str),1 do 
		local this_char = string.sub(str,i,i)
		if i > 1 then -- any command with a space following the slash should return nil/error
			if i == string.len(str) then 
				return str,""
			elseif this_char == " " then 
				return string.sub(str,1,i - 1),string.sub(str,i + 1)
			end
		end
	end
	return --error
end

function Console:split_parse(str,sep,pairchars)
--i didn't put this in under the string class because reasons
	pairchars = pairchars or {
--		["{"] = "}", --since this is only for commands, arguments should never be in table form
--		["("] = ")",
--		["\'"] = "\'",  --apostrophes are verboten as characters in short commands; please use full quotation marks "" instead (each opening quote must have a closing quote)
		["\""] = "\""
	}
	if not (sep and str and type(pairchars == "table")) then 
		--log error: bad input
		return
	end
	
	str = tostring(str)
	sep = tostring(sep)
	
	local enclosing = {} --table containing all levels of relevant enclosing characters; removes latest when pair is found
	
	local function e()
		return enclosing[#enclosing]
	end
	
	local new = {}
	local result = string.split(str,sep)
	local start_index
	local end_index
	for i,s in pairs(result) do --in all individual words/split substrings:
--		self:Log(s,{color = Color.green})
		for opening,closing in pairs(pairchars) do --check for opening/closing chars
			local e = e()
			local o = string.match(s,opening)
			local c = string.match(s,closing)
			if e then 
				if c and (pairchars[e] == closing) then 
					end_index = i
					enclosing[#enclosing] = nil
--					self:Log("Found closer " .. tostring(closing))
					break
				end
			end
			if o then
				if (o and c) and (o < c) then 
--					self:Log("open and close found in same word")
				else
					table.insert(enclosing,opening)
					start_index = start_index or i
--					self:Log("Found opener " .. tostring(opening))
					break
				end
			end
		end
		if start_index then 
			if end_index then 
				local r
				for i = start_index,end_index,1 do 
					if r then 
						r = r .. sep .. result[i]
					else
						r = result[i]
					end
--					self:Log(result[i],{color = Color(1,0,1)})
				end
				start_index = nil
				end_index = nil
--				self:Log("*",{color = Color.green})
				
				table.insert(new,r) --add un-separated concat string 
--				table.insert(new,result[i])
			end
		else
			table.insert(new,s) --add as usual
		end
	end
	
	return new
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

function Console:InterpretInput(input_str)
	--[[
		1. copy input string (do not modify original)
			a. remove extraneous spaces
		2. evaluate type (cmd, lua)
		3. if necessary, parse and format into readable lua result string;
			this includes searching for cmd and redirecting to proper function
		4. take result and convert to func with loadstring
		5. return func; do not execute, as this should be decided + handled by caller
	--]]
	local result = tostring(input_str)
		
	if (not input_str) or (string.len(result) <= 0) then 
		self:Log("ERROR: Console:InterpretInput(" .. input_str .. ") failed: bad input string",{color = Color.red})
		return
	end
	local func
	local space_len = 0
	local banned_chars = { --characters that will be removed from the front of a command; currently just empty space
		[" "] = true
	}
	for i = 1, string.len(result),1 do  --remove banned characters
		if banned_chars[string.sub(result,i,i)] then 
			space_len = i
		else
			break --if next character is not banned
		end
	end
	if space_len > 0 then --check valid 
		result = string.sub(input_str,space_len)
	end
	local func,error_msg
	local args,cmd_id,command
	local argument_string = ""
	local is_command
	local postargs
	
	if result == "" then 
		--don't even bother throwing an error
		return
	end
	
	if string.sub(result,1,1) == "/" then 
		if result == "//" then --repeat last
			local history_data = self.command_history[#self.command_history] or {}
			func = history_data.func
			result = history_data.name
			if not (result and func) then 
				self:Log("No command history found")
				return
			end
		else
			is_command = true
--			self:Log(tostring(is_command) .. "?")
			if string.match(result,"'") then 
				string.gsub(result,"'","\\'")
--				self:Log("ERROR: Console:InterpretInput(" .. input_str .. ") failed: apostrophe (') is not allowed. Please use a set of quotation marks (\") instead.",{color = Color.red})
--				return
			end
			result = string.sub(result,2) -- remove beginning forward slash (/)

			cmd_id,result = self:split_cmd(result) --remove cmd_id from input_str
			if not cmd_id then 
				self:Log("Invalid command!",{color = Color.red})
				return
			end
			command = self.command_list[cmd_id]
--			self:Log("cmd_id " .. cmd_id)
			if not command then
				self:Log("> " .. input_str,{color = Color.white:with_alpha(0.7),h_margin = 0}) 
			
				self:Log("No such command found: " .. "/" .. tostring(cmd_id),{color = self.color_data.fail_color})
				return 
			end
			postargs = command.postargs
			args = self:split_two(result,postargs)
--				self:t_log(args,"args")

			if #args > 0 then 
				argument_string = "'" .. string.gsub(table.concat(args,","),",","','") .. "'"
			end
			if command.str then 
				result = string.gsub(command.str,"$ARGS",argument_string) --format with arguments
			elseif cmd_id then 

				self:Log("> " .. input_str,{color = Color.white:with_alpha(0.7),h_margin = 0}) --log the input str to console
				self:Log("No such command found: " .. "/" .. tostring(cmd_id),{color = self.color_data.fail_color})
				return
			else
				self:Log("Error: empty command",{color = self.color_data.fail_color})
--				return
			end
		end
	end
	
	self:Log("> " .. ((is_command and input_str) or result),{new_cmd = true,color = Color.white:with_alpha(0.7),h_margin = 0}) --log the input str to console
	if not func then 
		func,error_msg = loadstring(result) --convert finished result to func
	end
	if error_msg then 
		self:Log("Compilation of string " .. tostring(input_str or "") .. " failed: " .. error_msg,{color = Color.red})
	elseif func then
		--compilation successful

		return func,(is_command and input_str) or result
	end
	self:Log("ERROR: Console:InterpretInput(" .. input_str .. ") failed- reason unknown",{color = Color.red})
	return 
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
	local frame = panel:child("command_history_frame")
	local history = frame:child("command_history_panel")
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
	elseif k == Idstring("`") then --its own conditional since i don't want ` as input since i'm binding it to console
		if shift_held then 
			new_char = "~"
		end
	else
		local ids = self:GetCharList()[tostring(k)]
		if ids then 
			if shift_held then 
				if k == Idstring("3") and self:GetKeyboardRegion() == "uk" then 
					--so something about text:replace() doesn't work right with the pound symbol
					--instead, i have to macro it in with string.gsub()
					
					new_char = "$POUND_SYMBOL"--string.char(194)
					--self.loathing = self.loathing + 999
					--hahah i made a funny joke
				else
					new_char = tostring(ids.uppercase or "_")
				end
			else
				new_char = tostring(ids.lowercase or "_")
			end
		end
	end
	if new_char then 
		self.selected_history = false
		text:replace_text(new_char)
		text:set_selection(s+1,s+1)
		text:set_alpha(1)
		
		if string.len(text:text()) > 0 then 
			text:set_text(string.gsub(text:text(),"$POUND_SYMBOL","£")) --extremely hacky workaround.
		end
		
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
			
			if new_text then 
				if not self.selected_history then 
--					self:Log("ERROR! No self.selected_history for DOWNARROW input",{color = Color.red})
				elseif self.selected_history <= 0 then
					text:set_alpha(1)
					text:set_text(new_text)
				else
					text:set_alpha(0.5)
					text:set_text(new_text)
				end

				current_len = new_text and string.len(tostring(new_text))
				
				--do not change selection
--				self:Log("Success for selection index " .. tostring(self.selected_history))
			else
--				self:Log("No new_text for selection index " .. tostring(self.selected_history),{color = Color.yellow})
			end
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
			end
		elseif k == Idstring("home") then 
			text:set_selection(0, 0)
		elseif k == Idstring("end") then 
			text:set_selection(n, n)
		elseif k == Idstring("page up") then 
		
			history:set_y(math.min(history:y() + frame:h(),0))
			self:refresh_scroll_handle()
			
--			history:set_y(history:y() - (Console.settings.scroll_page_speed))

			self:refresh_scroll_handle()
		elseif k == Idstring("page down") then 
--			history:set_y(history:y() + (Console.settings.scroll_page_speed))

			local bottom_scroll = frame:h() - history:h()
			if (history:y() + history:h() > frame:h()) then 
				history:set_y(math.max(bottom_scroll,history:y() - frame:h()))
			else
				history:set_y(bottom_scroll)
			end
			

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

	self:update_hud_popups(t,dt)
	
	self:update_persist_scripts(t,dt)
	
	self:update_restart_timer(t,dt)
	
		--[[
	local player = managers.player:local_player()
	if player then 
		local movement = player:movement()
		local head_pos = movement:m_head_pos()
		local head_angle = movement:m_head_rot():y().y
		local head_rot = mvector3.copy(movement:m_head_rot():y())
		local yaw = math.deg(head_rot)
		Console:SetTrackerValue("trackera",tostring(yaw))
		Console:SetTrackerValue("trackerb",tostring(movement:m_head_rot()))
		Console:SetTrackerValue("trackerc",tostring(movement:m_head_rot():yaw()))
		Console:SetTrackerValue("trackerd",tostring(movement:m_head_rot():pitch()))
		Console:SetTrackerValue("trackere",tostring(movement:m_head_rot():roll()))	
	end
		--]]
	
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
	local team = hud:child("info_unit_team")
	local unit_marker = hud:child("marker")
	
	local visible = self.show_debug_hud
	self._debug_hud:set_visible(self.show_debug_hud)
	if not visible then 
		return
	end
	self:GenerateHitboxes()
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
	if unit and alive(unit) and unit:character_damage() and unit:base() then 
		local unit_pos = unit:position()
--unit:movement():team() ~= self._unit:movement():team() and unit:movement():friendly_fire()
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
		
		--*************STUFF GOES HERE THAT IS VERY IMPORTANT
--[[
		Console:SetTrackerValue("trackera",tostring(mvector3.distance_sq(player:position(), unit:position())))
--		Console:SetTrackerValue("trackerc",tostring(head_pos - viewport_cam:position()))
--		Console:SetTrackerValue("trackere",tostring(angle_to_person))
local angle_between_asdkfjalsd = self:angle_between_pos(head_pos,viewport_cam:position())
		self:SetTrackerValue("trackera",viewport_cam:rotation():yaw() % 360)
		self:SetTrackerValue("trackerb",angle_between_asdkfjalsd)
		self:SetTrackerValue("trackerc",(angle_between_asdkfjalsd + -viewport_cam:rotation():yaw() + -90) % 360)
		self:SetTrackerValue("trackerb",mvector3.distance(head_pos,viewport_cam:position()))
		--]]
		--*************VERY IMPORTANT STUFF 
		
		name:set_text(tostring(unit:base()._tweak_table or "ERROR"))
		name:set_color(Color.yellow)
		team:set_text(tostring(unit:movement():team().id))
		team:set_color(Color.yellow)
		hp:set_text(tostring(unit:character_damage()._health))
		hp:set_color(Color.yellow)
--		unit_marker:set_color(is_tagged and Color.red or Color.white)
		unit_marker:set_alpha(is_tagged and 1 or 0.3)
--		unit_marker:set_visible(true)
	else
		unit_marker:set_alpha(0)
		team:set_text("NO DATA")
		name:set_text("NO DATA")
		hp:set_text("NO DATA")
		team:set_color(Color.red:with_alpha(0.3))
		name:set_color(Color.red:with_alpha(0.3))
		hp:set_color(Color.red:with_alpha(0.3))
--		unit_marker:set_visible(false)
	end
end

function Console:update_custom_keybinds(t,dt)
	if not self._custom_keybinds then
		return
	end
	for _id,keybind_data in pairs(self._custom_keybinds) do 
		local id = tostring(_id)
--[[		
		if _id == id then 
			self:SetTrackerValue(id,tostring(HoldTheKey:Key_Held(id)))
		else
			self:SetTrackerValue(id,string.len(_id) .. "different!" .. string.len(id))
		end
--]]		
--		local tracker = self:CreateTracker(id)
		
		local k_result,k_fail
		if keybind_data and type(keybind_data) == "table" then
			local k_category = keybind_data.category
	--		local held = HoldTheKey and HoldTheKey:Keybind_Held(keybind_id)
			local held
			if k_category == "bind_id" then 
				held = HoldTheKey:Keybind_Held(id)
--				tracker:set_text(k_category .. " =2= " .. tostring(held))
			elseif k_category == "key_name" then 
				held = HoldTheKey:Key_Held(id)
--				tracker:set_text(k_category .. " =1= " .. tostring(held))
			end
			if held and ((not self._keybind_cache[id]) or keybind_data.persist) then
				if keybind_data.func then 
					if type(keybind_data.func) == "function" then 
						k_result,k_fail = pcall(keybind_data.func)
						if not (k_result or keybind_data.persist) then 
							self:Log("Keybind [" .. id .."] execution failed",{color = Color.red})
						end
					end
				end
			end
			self._keybind_cache[id] = held
		end
--		tracker:set_text("id = " .. id .. ', cat = ' .. tostring(k_category) .. ", held = " .. tostring(held or false))
	end
	
end

function Console:update_restart_timer(t,dt)
	--if host then blah blah blah
	if self._restart_timer_t then --time at which heist will restart
		local time_left = math.ceil(self._restart_timer_t - t) --seconds left to restart
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
		local bottom_scroll = frame:h() - history:h()
		if self:held(mwu) then --console scroll
		
			if (history:y() + history:h() > frame:h()) then 
				new_y = math.max(bottom_scroll,history:y() - scroll_speed)
			else
				new_y = bottom_scroll
			end
			history:set_y(new_y)
			self:refresh_scroll_handle()
		elseif self:held(mwd) then 
			new_y = math.min(history:y() + scroll_speed,0)
			history:set_y(new_y)
			self:refresh_scroll_handle()
		end
		self:SetTrackerValue("trackera","history y:" .. tostring(history:y()))
--		self:SetTrackerValue("trackerb","max position " .. bottom_scroll)
--		self:SetTrackerValue("trackerb","history h " .. history:h())
--		self:SetTrackerValue("trackerc","history bottom " .. history:bottom())
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

function Console:refresh_scroll_handle(adjust_pos)

	local panel = self._panel
	local frame = panel:child("command_history_frame")
	local history = frame:child("command_history_panel")
	local scroll_handle = panel:child("scroll_handle")
	
	local block_bottom = panel:child("scroll_block_bottom")
	local bottom_y = block_bottom:top()
	
	local block_top = panel:child("scroll_block_top")
	local top_y = block_top:bottom()
	
	if adjust_pos then 
--		scroll_handle:set_y(
	end
	
	local scroll_handle_height = (bottom_y - top_y) --max height
	local bottom_range = 0
	local top_range = history:h() - frame:h()



	local num_lines = self.num_lines
	local result --height of scrcoll handle (diminishes with length)
	if num_lines > 246 then
		result = 10
--		scroll_handle:set_h(self.num_lines
	else
		result = scroll_handle_height * ((256 - num_lines) / 256)
		
		scroll_handle:set_h(result)
	end



--handle height is dictated by the distance to the two blocks
	local ratio = math.abs((history:y() - bottom_range) / top_range)
	local handle_y = top_y + (ratio * (scroll_handle_height - result))
	
	scroll_handle:set_y(handle_y)
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

function Console:GenerateHitboxes(mask,radius,distance) --slight misnomer, it just generates the debug shapes of the hitboxes, not the actual hitboxes themselves
	local slot_mask = managers.slot:get_mask(mask or "enemies" or "bullet_impact_targets")
	local player = managers.player:local_player()
	if not player then return end
	local cam = player:camera():camera_object()
	local center = Vector3(0,0)
	radius = tonumber(radius or 0.9)
	distance = tonumber(distance or 1000)
	size = 10
	
	--todo armor hitbox stuff
	--[[
	local fwd_ray = self:GetFwdRay()
	if fwd_ray and fwd_ray.unit and fwd_ray.body then 
		if fwd_ray.body and fwd_ray.body:name() == Idstring("body_plate") then 
			self._tagunit_brush:sphere(fwd_ray.position,3)
		end
	end
	--]]
	
	local tagged_pos = self:GetTaggedPosition()
	if tagged_pos then --and (type(Console.tagged_position) == "Vector3") then 
		self._tagworld_brush:sphere(tagged_pos,30)
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
		Console:ResetSettings() --todo confirm prompt
	end

	MenuCallbackHandler.commandprompt_keybind_debughud = function(self)
		Console.show_debug_hud = not Console.show_debug_hud
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
	
	MenuCallbackHandler.commandprompt_setkeyboardregion = function(self,item)
		Console.settings.keyboard_region = tonumber(item:value())
		Console._console_charlist = nil --to require regenerating the charlist again next input
	end
	
	MenuCallbackHandler.commandprompt_setprintbehavior = function(self,item)
		Console.settings.print_behavior = tonumber(item:value())
	end
	
	MenuCallbackHandler.commandprompt_setprintbehavior = function(self,item)
		Console.settings.print_behavior = tonumber(item:value())
	end
	
	MenuCallbackHandler.commandprompt_toggle = function(self) --keybind
--		log("*********************Pressed Console togglebutton")
		if (Input and Input:keyboard() and not Console:_shift()) then 
			Console:ToggleConsoleFocus()
		end
	end	
	MenuCallbackHandler.callback_dcc_close = function(self)
		Console:Save()
	end

--	Console:Load()
	Console:LoadKeybinds()
	
	Console:_create_commandprompt(1280,700)
	MenuHelper:LoadFromJsonFile(Console.options_path, Console, Console.settings) --no settings, just the two keybinds
end)

function Console:_create_commandprompt(console_w,console_h)
--		log("CONSOLE: Error: bad parent panel")
--	Console._menu = managers.menu:register_menu("console_menu")
	Console._ws = Console._ws or managers.gui_data:create_fullscreen_workspace()
	local ws = Console._ws:panel()
--	local orig_hud = managers.menu_component and managers.menu_component._fullscreen_ws --or managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2).panel
	
	console_w = console_w or ws:w()
	console_h = console_h or ws:h()
	
	local font_size = Console:GetFontSize()
	
	local h_margin = Console.h_margin
	
	local v_margin = Console.v_margin
	
	local debug_hud_base = ws:panel({
		name = "debug_hud_base", --used for trackers
		visible = true
	})
	Console._debug_hud = debug_hud_base
	
	local unit_marker = debug_hud_base:bitmap({
		name = "marker",
		texture = "guis/textures/access_camera_marker",
		layer = 02,
		color = Color.white,
		x = 1,
		y = 1
	})
	
	local unit_name = debug_hud_base:text({
		name = "info_unit_name",
		layer = 90,
		x = 700, --just to the right of crosshair
		y = 400,
		text = "unit_name",
		font = tweak_data.hud.medium_font,
		font_size = font_size,
		color = Color.white
	})
	
	local unit_hp = debug_hud_base:text({
		name = "info_unit_hp",
		layer = 90,
		x = 700, --just under unit name
		y = 420,
		text = "unit_hp",
		font = tweak_data.hud.medium_font,
		font_size = font_size,
		color = Color.white
	})
	
	local unit_team = debug_hud_base:text({
		name = "info_unit_team",
		layer = 90,
		x = 700, --just under unit hp
		y = 440,
		text = "unit_team",
		font = tweak_data.hud.medium_font,
		font_size = font_size,
		color = Color.white
	})
	

	local console_base = ws:panel({
		name = "console_base",
		visible = false --hidden by default, activated by keybind
	})
	
	Console._panel = console_base
	
	local console_bg = console_base:rect({
		name = "console_bg",
		layer = 98,
		color = Color.black:with_alpha(0.6)
	})
	local bg_blur = console_base:bitmap({
		texture = "guis/textures/test_blur_df",
		name = "bg_blur",
		valign = "grow",
		halign = "grow",
		render_template = "VertexColorTexturedBlur3D",
		layer = -2
	})
	bg_blur:set_size(console_base:size())

	local command_history_frame = console_base:panel({
		name = "command_history_frame",
		layer = 100,
		x = h_margin,
		y = 0,
		w = console_w,
		h = console_h - (v_margin + font_size)
	})

	
	local command_history_bg = command_history_frame:rect({
		name = "command_history_bg",
		layer = 99,
		h = console_h - (font_size + v_margin),
		visible = false, --draws in front of everything for whatever reason
		color = Color.black:with_alpha(0.1)
	})
	local command_history_panel = command_history_frame:panel({
		name = "command_history_panel",
		h = h_margin + 12, --increased with each Log()
		layer = 100
	})
	
	local history_size_debug = command_history_panel:rect({
		name = "history_size_debug",
		layer = 98,
		visible = false,
		color = Console.quality_colors.arc:with_alpha(0.5)
	})
		
	local scroll_handle = console_base:rect({
		name = "scroll_handle",
		layer = 101,
		w = 8,
		x = 2,
		h = console_h - font_size,
		color = Console.color_data.scroll_handle
	})
	
	local scroll_block_top = console_base:rect({	
		name = "scroll_block_top",
		layer = 102,
		w = 12,
		h = 12,
		y = 0,
		color = Color.white:with_alpha(0.7)
	})
	
	local scroll_block_bottom = console_base:rect({	
		name = "scroll_block_bottom",
		layer = 102,
		w = 12,
		h = 12,
		y = console_h - (v_margin + font_size + 12),
		color = Color.white:with_alpha(0.7)
	})
	
	local scroll_bg = console_base:rect({
		name = "scroll_bg",
		layer = 99,
		w = 12,
		h = console_h - (font_size + v_margin),
		color = Color.white:with_alpha(0.3)
	})
	
	local caret = console_base:text({
		name = "caret",
		layer = 103,
		x = h_margin,
		y = console_h - (font_size + v_margin),
		text = "|",
		font = tweak_data.hud.medium_font,
		font_size = font_size,
		color = Color.white:with_alpha(0.7)
	})
	
	local selection_box = console_base:rect({
		name = "selection_box",
		layer = 102,
		x = h_margin,
		y = console_h - (font_size + v_margin),
		w = 3,
		h = font_size,
		color = Color.white,
		blend_mode = "sub"
	})
	
	local input_text = console_base:text({
		name = "input_text",
		layer = 104,
		x = h_margin,
		y = console_h - (font_size + v_margin),
		text = "",
		font = tweak_data.hud.medium_font,
		font_size = font_size,
		blend_mode = "add",
		color = Color.white
	})

	local prompt = console_base:text({
		name = "prompt",
		text = "> ",
		layer = 102,
		x = 0,
		y = console_h - (font_size + v_margin),
		font = tweak_data.hud.medium_font,
		font_size = font_size,
		blend_mode = "add",
		color = Color.white
	})
	
	local input_bg = console_base:rect({
		name = "input_bg",
		layer = 101,
		h = font_size,
		y = input_text:y(),
		color = Color.black:with_alpha(0.7)
	})
	
	Console._charlist = Console:BuildCharList()
--	self:create_dot_test(ws)
	
end