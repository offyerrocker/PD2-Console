
--console stuff
--[[ TODO:
- Move cmd history properly when sending new commands

- Block all other input in console mode

- Change load priority to last load

- Overflow to newline (todo test \n functionality) for character limits (should check against max length setting)

- Add Log() callback so that manually calling Log() in the console only returns its result after displaying the original cmd string	
	
- Better error messages with assert() (https://www.lua.org/pil/8.html)	

- Scan for protected values; eg. do not allow console to change Console or its values. Instead, use cl_ commands	

- Straighten out history (It should be easy to get previous commands by number, without interference from other console_log lines)
	- Command history should be saved in a table, by index
	- Saved result should be the function result returned by loadstring() rather than the string, to save on perf/mem
	
- Standardize margins + values in hudmanagerpd2
- Enable Console in main menu
- Add vertical space between command pairs
- Add scroll bar that actually works, except no mouse support, sadly
- Fancy fadeout/fadein for command window
- Fancy texture(s) for command window
- Add settings
	- "Reset settings" button
	- Console window mover
- Separate into separate mod
- Add better highlight visibility
- Add special character actions:
	- UPARROW to choose prev command in history
	- DOWNARROW to choose next command in history
	- CTRL-Z support?
	- CAPSLOCK support?
	- SHIFT+RETURN for newline? (invisible to code, only for organization)
	- or append with ; (SEMICOLON) for multi-line commands
	- CTRL + (LEFTARROW/RIGHTARROW) to move cursor to next space/special char in left/right direction
	- ALT-code support?

- Add most console settings as cl_blanketyblank
- Add console commands (separate from Lua code execution):
	= Debug console commands:
		- log [msg] [name]: outputs to blt log; otherwise identical to _log()
		- c_log [msg] [name]: outputs to console; otherwise identical to c_log()
		- t_log/PrintTable [table] [optional: name] [optional: tier]: prints nicely-formatted table to console
	= Misc console commands:
		- about: display mod info/hash
		- help: output a list of all (read: most) commands and their descriptions
		- //: execute previous command/code again
		- say: output result to chat
		- quit: Application:close() (after confirm prompt)
		- restart [sec]: initiate restart after [sec] seconds; default 5/0?
		- playsound [id] [sync]: plays soundfile with string id [id]. if [sync], is audible to other players
		- wait [s]; delayed callback?
		- fov [num]: sets FOV to this number
		- sensitivity [num]: sets mouse sensitivity to this number
		- sensitivity_aim [num]: sets mouse sensitivity to this number
		- ping [optional: peerid]: displays ping to all clients, or specified client; output "you're in offline mode, dumbass" if offline
		- other client settings?
		- date: returns Application:date()
		- time: returns the current real-world time
		- writetodisk [data] [pathname]: Writes data to a (default txt) file in JSON format; todo figure out boundaries to where I can save that shit
			- if pathname is unparseable, save to default location and write error message detailing save location
		- stop: stops all jokes, command processes, sounds, and registered running callback/functions

- Determine console prefix (probably "/")
	
- Add command tooltip/syntax/error/usage	
	
--]]


_G.Console = {}

Console.settings = {
	font_size = 12,
	margin = 2,
	scroll_speed = 12, --pixels per scroll action
	scroll_page_speed = 800, --pixels per page scroll action
	esc_behavior = 1
}

Console.path = ModPath
Console.options_name = "options.txt"
Console.options_path = Console.path .. "menu/" .. Console.options_name
Console.save_name = "command_prompt_settings.txt"
Console.save_path = SavePath .. Console.save_name
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
Console.input_t = 0 --last t of valid character/text input
--Console._panel = panel
Console._enter_text_set = true --i'm... not totally sure what that does
Console._delayed_result = nil --stores the result of pcalled Log(), so that it can be displayed in order

Console.color_data = {
	scroll_handle = Color(0.1,0.5,0.8)
}

Console.h_margin = 24
Console.v_margin = 3

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

function Console:GetEscBehavior()
	return self.settings.esc_behavior
end

function Console:string_excise(str,s,e,replacement)
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

function Console:Log(info,params)
	local color = params and params.color or Color.white
	
	if not info then
--		return --todo setting to disable logging if nil value? optional parameter?
	end
	
	local line = self.num_lines
	local new_line = self:new_log_line()
	if new_line and alive(new_line) then 
		new_line:set_color(color) 
		new_line:set_text(tostring(info))
	end
end

function Console:new_log_line()
	local panel = self._panel
	local frame = panel:child("command_history_frame")
	local history = frame:child("command_history_panel")
	local line
	local font_size = self:GetFontSize()
	local v_margin = self.v_margin
	local h_margin = self.h_margin
	history:set_h(history:h() + font_size + v_margin)
	if not history:child("history_cmd_" .. tostring(self.num_lines)) then 
		line = history:text({
			name = "history_cmd_" .. tostring(self.num_lines),
			layer = 1,
			x = h_margin + 16, --margin
			y = (2 + self.num_lines) * (font_size),
			text = "[" .. tostring(self.num_lines) .. "] loading...",
			font = tweak_data.hud.medium_font,
			font_size = font_size,
			color = Color.white:with_alpha(0.5)
		})
	else
		log("ERROR! history line " .. tostring(self.num_lines) .. " already exists!")
	end
	self.num_lines = self.num_lines + 1
	return line
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

Hooks:Add("LocalizationManagerPostInit", "commandprompt_addlocalization", function( loc )
	loc:add_localized_strings(
		{
			commandprompt_menu_title = "Console Options"
		}
	)
end)	

Hooks:Add("MenuManagerInitialize", "commandprompt_initmenu", function(menu_manager)
	MenuCallbackHandler.commandprompt_quitgame = function(self)
	--[[
		local title = managers.localization:text("sws_bind_info_title")
		local desc = managers.localization:text("sws_bind_info_long")
		local options = {
			{
				text = managers.localization:text("sws_ok"),
				is_cancel_button = true
			}
		}
		QuickMenu:new(title,desc,options,true)
		--]]
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
		Console:ToggleConsoleFocus()
	end
	MenuHelper:LoadFromJsonFile(Console.options_path, Console, Console.settings) --no settings, just the two keybinds
end)

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

function Console:DelayedLog(info)
	self._delayed_result = info --save result as it is given,
	return tostring(info) --but return in string format to be logged
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

function Console:enter_key_callback()

	local panel = self._panel
	local text = panel:child("input_text")
	local cmd = text:text()
	local cmd_len = string.len(cmd)
	if cmd_len <= 0 then	
		return
	else
		local space_len = 0
		for i=1,cmd_len,1 do 
			if string.sub(cmd,i,i) == " " then --remove all spaces from the start of a command
				space_len = i
			else
				break
			end
		end
		if space_len > 0 then 
			cmd = string.sub(cmd,space_len,cmd_len)
		end
	end
	if cmd == "" or (string.len(cmd) <= 0) then 
		return 
	end
	local orig_cmd = cmd
	cmd = "Console:DelayedLog(" .. cmd .. ")" --save the result of the cmd string to log later
	--todo delayed callback to log so we can determine if it was a successful cmd that didn't output,
	--or an unsuccessful command 
	--save result as a var?
	log(tostring(cmd))
	if pcall(loadstring(cmd)) then
		self:Log("> " .. orig_cmd) --log the cmd string (before modifying to add console_log result)
		if self._delayed_result then 
			self:Log(self._delayed_result)
		end
	else
		self:Log("> " .. orig_cmd)
		self:Log("Command failed",{color = Color.red})
	end
	self._delayed_result = nil
	
	text:set_text("")
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


function Console:key_press(o,k)
	local panel = self._panel
	local text = panel:child("input_text")
	local debug_text = panel:child("debug_text")
	self.input_interval_done = false

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
			self:enter_key_callback()
		end
	end

	local current = text:text()
	local current_len = string.len(current)
	if k == Idstring("delete") then 

	elseif k == Idstring("insert") then 
		text:set_text(self:string_excise(current,s,e,clipboard))
		text:set_selection(s,s + string.len(clipboard))
	elseif k == Idstring("left") then 
	elseif k == Idstring("right") then 
	elseif k == Idstring("up") then 
	elseif k == Idstring("down") then 
	elseif k == Idstring("home") then 
	elseif k == Idstring("end") then 
	elseif k == Idstring("page up") then 
	elseif k == Idstring("page down") then 
	elseif k == Idstring("esc") and type(self._esc_callback) ~= "number" then
		
		self:esc_key_callback()
		--options:
		--1. clear current line
		--2. if line is empty, close console; else clear current line
		--3. close console
	elseif k == Idstring("a") and ctrl_held then 
		if current_len > 0 then
			text:set_selection(0,current_len)
		end
		return
	elseif k == Idstring("v") and ctrl_held then
		text:set_text(self:string_excise(current,s,e,clipboard))
		text:set_selection(s,s + string.len(clipboard))
		return --do not set key pressed and add "v" char
	elseif k == Idstring("z") and ctrl_held then 
		return --same; ctrl-z is not implemented yet
	elseif k == Idstring("a") and ctrl_held then 
		--select all
	else
--		return
	end

	self._key_pressed = k
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
			text:set_text(self:string_excise(current,s,e,new_char))
			text:set_selection(e,e)
		end

	else
		if k == Idstring("backspace") then --delete selection or text character behind caret
			if s == e and s > 0 then
				text:set_selection(s - 1, e)
			end

			text:replace_text("")
			
		elseif k == Idstring("delete") then --delete selection or text character after caret
			
			if s == e and s < n then
				text:set_selection(s + 1, e)
			end

			text:replace_text("")

		elseif k == Idstring("insert") then 
			--nothing? todo decide if "paste clipboard" should be auto-repeatable
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
				self._caret_blink_t = t
			end
		elseif k == Idstring("up") then 
		
		elseif k == Idstring("down") then 
		
		elseif k == Idstring("home") then 
			text:set_selection(0, 0)
		elseif k == Idstring("end") then 
			text:set_selection(n, n)
		elseif k == Idstring("page up") then 
			history:set_y(history:y() - (Console.settings.scroll_page_speed))
			--move history window up by 14 * (math.floor(frame:h() / 14))
		elseif k == Idstring("page down") then 
			history:set_y(history:y() + (Console.settings.scroll_page_speed))
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
