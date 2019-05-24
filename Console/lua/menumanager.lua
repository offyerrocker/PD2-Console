--[[ TODO: FEATURES BEFORE PUBLIC 1.0

tracker: auto-detect changes
	-support callbacks?

wrap Debug HUD unit info in nice safe pcall()

add more unit info 

add unit info keybind to hide interface

add unit info /shortcommands to display info (accessible through chat)

add waypoint to selected unit
	- crawl through hudmanager for waypoint code


- Enable Console in main menu (init console window somewhere other than where it is in hudmanager)
	
- Create Debug HUD
	- create cool looking ui for unit info (using hud assets? think bounding box; see camera unit-spotting code for example)

	
		
- Add backup chat commands (hidden by default)
	
	
Keybinds:
	- Set position waypoint at fwd_ray
	- Select Unit at fwd_ray
		- Select enemy at fwd_ray
			* Hold [modifier key] to select enemy and freeze AI
		- Select deployable at fwd_ray
		- Select misc object at fwd_ray



- Add scroll bar that actually works, except no mouse support, sadly
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
	
	

- Keybind callbacks + script exec trackers (/bind stuff)

- Optionally, allow overriding log() function
	- Add console command "enablelogs" to enable/disable BLT logs or something

- Add settings
	- "Reset settings" button
	- Console window mover in mod options


- Add basic debug commands:
	- log [msg] [name]: outputs to blt log; otherwise identical to _log()
	- c_log [msg] [name]: outputs to console; otherwise identical to c_log()
	- t_log/PrintTable [table] [optional: name] [optional: tier]: prints nicely-formatted table to console




---extra features, for post release

- re-absorb upd_caret to update_scroll for var efficiency

- Instead of adding vspace by value, check against previous log's xy/wh values and add to those (also solves v whitespace issue)
	- Add remaining passed params to new_log_line()
	- Fix new_log_line() text height calculation (string.match count for "\n"?)
	- Move cmd history properly when sending new commands
	- Restore replaced text if selected_history == 0

- Scan for \n in strings, and replace with separate Log() line
	- Overflow to newline for character limits (should check against max length setting)
		- \n works for standard strings and hud text panels
		
- Add command tooltips

- Add remaining syntax + usage + /help

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
	- CAPSLOCK support?
	- SHIFT+RETURN for newline? (invisible to code, only for organization)
	- CTRL + (LEFTARROW/RIGHTARROW) to move cursor to next space/special char in left/right direction
	- ALT-code support?

- Implement GetConsoleAddOns hook for third-party command modules /persist callback scripts etc

-----------------
changes from last version:

added global Log() function that redirects to Console:Log()

reorganized persist scripts: console now organizes its update functions into a single update() called from exec_persist.lua (todo rename this)
-	moved update to persist script rather than hudmanager update, for better custom hud compatibility
-	changed key held check held() to Console class function rather than local function; moved function to menumanager with everything else rather than hudmanage

Debug HUD unit info is now in early functional phases of development

HUD Tracker is now functional

Officially added HoldTheKey as dependency

/quit now accepts "true" as its first argument, which skips the confirm dialogue

/restart now properly accepts and uses timer from its first and only argument, and outputs this timer progress to console every second
this timer can now be cancelled with /restart cancel

short /commands now properly process arguments as strings
added syntax + usage messages for most commands with arguments, if the first non-command argument (aka subcommand or "subcmd") provided is equal to "help"
short /commands now properly process arguments without an extra, erroneous comma if there is no second argument

/whisper implemented (needs testing)

trackers can now be listed and selected by number with "/tracker list" and "/tracker select [number]"

command history is now 70% alpha; other logs are 100% alpha by default (changed from universal 70% alpha)

selected_unit can now be created with a keybind

changed horizontal margin for console window text: logged results are indented while command history is not

console toggle button is disabled while holding shift (so that "~" can be used for "~=" compare operators if bound to `)  

organized function orders in menumanager (mostly cosmetic)

-more stuff i forgot right now

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

--todo slap these in an init() function and call it at start

Console.command_history = {
--	[1] = { name = "/say thing", func = (function value) } --as an example
}

Console.color_data = { --for ui stuff
	scroll_handle = Color(0.1,0.3,0.7)
}

Console.cmd_list = { --in string form so that they can be called with loadstring() and run safely in a pcall; --todo update
	help = "Console:cmd_help($ARGS)", --nothing useful
	about = "Console:cmd_about()", --nothing useful 
	info = "Console:cmd_info($ARGS)", --nothing useful
	say = "Console:cmd_say($ARGS)",
	whisper = "Console:cmd_whisper($ARGS)",
	tracker = "Console:cmd_tracker($ARGS)",
	god = "OffyLib:EnableInvuln($ARGS)", --sorry kids you don't get the kool cheats unless you're me
	exec = "Console:cmd_dofile($ARGS)",
	["dofile"] = "Console:cmd_dofile($ARGS)", --don't you give me your syntax-highlighting sass, np++, i know dofile is already a thing
	bind = "Console:cmd_bind($ARGS)",
	unbind = "Console:cmd_unbind($ARGS)",
	time = "Console:cmd_time()",
	date = "Console:cmd_date()",
	quit = "Console:cmd_quit($ARGS)",
	restart = "Console:cmd_restart($ARGS)", --argument is seconds delay to restart
--	fov = "Console:cmd_fov($ARGS)", -- borked atm
--	ping = "Console:cmd_ping($ARGS)", --not implemented
	savetable = "Console:cmd_writetodisk($ARGS)", -- [data] [pathname]
--	adventure = "Console:cmd_adventure($ARGS)",
	stop = "Console:cmd_stop($ARGS)"
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

function Console:OnInternalLoad() --called on event PlayerManager:_internal_load()
	--load keybinds
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

function Console:cmd_bind(keybind_id,func,held,...) --func is actually a string which is fed into Console's command interpreter
--todo popup box req HoldTheKey
	if (keybind_id == "help") and (not func) then 
		self:Log("Syntax: /bind [string: keybind_id] [callback/command string: func] [optional bool: held]",{color = Color.yellow})
		self:Log("Usage: Bind a key to execute a Lua snippet or Console commmand.",{color = Color.yellow})
		return
	end
	if keybind_id then --todo check blt.keybinds for valid keybind registration
		if self._custom_keybinds[keybind_id] or not func then --if nil or invalid func parameter then show current bind
			return self._custom_keybinds[keybind_id] --todo output to log
		elseif func then 
			self._custom_keybinds[keybind_id] = {
				persist = held or false,
				func = func
			}
		end
	end
end

function Console:cmd_help(cmd_name)
	self:Log("new mod who dis?",{color = Color.yellow})
	return
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
		Application:close()
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
	end
	timer = timer and tonumber(timer)
	if not timer or timer <= 0 then 
--		self:Log("Restarted the game! JK",{color = Color.green})
		managers.game_play_central:restart_the_game()
	elseif timer then 
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

function Console:GetFwdRay()
	local player = managers.player:local_player()
	return player and player:movement():current_state()._fwd_ray
end

function Console:SetFwdRayUnit(unit)
	if unit then --and not filtered_type(unit)
		self.selected_unit = unit
	end
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
		local command = cmd_id and self.cmd_list[cmd_id] 
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
		if s == e then --insert text at (after) caret
			if s >= current_len then --insert at end; implicitly s > 1
				text:set_text(current .. new_char)
				text:set_selection(s+1,s+1)
			elseif s <= 1 then --insert at start
				text:set_text(new_char .. current:sub(1,current_len))
				text:set_selection(s+1,s+1) --todo TEXT-INS mode?
			elseif s < current_len then --insert somewhere in middle
				text:set_text(current:sub(1,s) .. new_char .. current:sub(s + 1,current_len))
				text:set_selection(s+1,s+1)
			end
		elseif s ~= e then --replace selection
			text:replace_text(new_char)
--			text:set_text(self:string_excise(current,s,e,new_char))
			text:set_selection(e,e)
		end
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
			if not self.selected_history then 
				self.selected_history = 1 --set at newest command
			else
				if self.selected_history >= num_commands then 
					self.selected_history = 1
--					self:Log(self.selected_history .. ">=" .. num_commands)
				elseif num_commands > 1 then
					self.selected_history = self.selected_history + 1
--					self:Log(num_commands .. ">" .. 1)
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
		elseif k == Idstring("up") then 
			if not self.selected_history then 
				self.selected_history = num_commands --set at oldest command
			else
				if self.selected_history <= 1 then 
					self.selected_history = num_commands
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
	
	
	
	local fwd_ray = self:GetFwdRay() or {}
	
	local unit = fwd_ray.unit
	
	local pos = fwd_ray.position
	
	if unit and alive(unit) and unit:character_damage() and unit:base() then 
		name:set_text(tostring(unit:base()._tweak_table or "ERROR"))
		name:set_color(Color.yellow)
		hp:set_text(tostring(unit:character_damage()._health))
		hp:set_color(Color.yellow)
	else
		name:set_text("NO DATA")
		name:set_color(Color.red:with_alpha(0.3))
		hp:set_text("NO DATA")
		hp:set_color(Color.red:with_alpha(0.3))
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
	MenuCallbackHandler.commandprompt_selectfwdrayunit = function(self)
		local fwd_ray = Console:GetFwdRay()
		local unit = fwd_ray.unit
		if unit then 
			Console:SetFwdRayUnit(unit)
		end
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
