--[[
goals:
- functional ui!!!!
- better arg tagging (eg. "echo $examplevar -p whatever -s asdf" )
- better func documentation

- session pref

-selection text color

slightly more bash-like

"/" key shortcut to open console window

hook based autoexec system in saves?
warning/text-based confirm prompt eg. when a query is expected to have lots of results
set escaping: change character set to include punctuation and alphanumeric chars

- queue messages before console is initiated
- welcome message on startup

commands:
	/setvar var value

beardlib optional (but still recommended)

-- // executes previous stored loadstring function
-- /// re-evaluates and executes previous stored input

echo/print - print result or results to console
	- echo should be mainly for vars

- registry system to store results of previous command


command to clear logs
--]]



Console = Console or {}
do --init mod vars
	local save_path = SavePath
	local mod_path = ConsoleCore and ConsoleCore:GetPath() or ModPath
	Console._mod_core = ConsoleCore
	Console._mod_path = mod_path
	Console._menu_path = mod_path .. "menu/options.json"
	Console._default_localization_path = mod_path .. "localization/english.json"
	Console._save_path = save_path .. "console_settings.ini"
	Console._output_log_file_path = save_path .. "console_output_log.txt" --store recent console output; colors and data types are not preserved
	Console._input_log_file_path = save_path .. "console_input_log.txt" -- store recent console input
	Console.console_window_menu_id = "console_window_menu" --not used
	Console.default_palettes = {
		"ff0000",
		"ffff00",
		"00ff00",
		"00ffff",
		"0000ff",
		"880000",
		"888800",
		"008800",
		"008888",
		"000088",
		"ff8800",
		"88ff00",
		"00ff88",
		"0088ff",
		"8800ff",
		"884400",
		"448800",
		"008844",
		"004488",
		"440088",
		"ffffff",
		"bbbbbb",
		"888888",
		"444444",
		"000000"
	}
	Console.color_setting_keys = { --unfortunately, all settings that are hex color strings must be identified here so that they can be properly read/written by the ini parser
		"window_text_normal_color",
		"window_text_highlight_color",
		"window_text_stale_color",
		"window_text_selected_color",
		"window_input_box_color",
		"window_button_normal_color",
		"window_button_highlight_color",
		"window_bg_color",
		"window_caret_color",
		"window_prompt_color"
	}
	Console.palettes = table.deep_map_copy(Console.default_palettes)
	Console.default_settings = {
		safe_mode = false,
		input_log_enabled = true,
		output_log_enabled = true,
		log_buffer_enabled = true,
		log_buffer_interval = 10, --seconds between flushes
		window_scrollbar_lock_enabled = true,
		window_scroll_direction_reversed = false,
		window_text_normal_color = 0xffffff,
		window_text_highlight_color = 0xffd700, --the color of the highlight box around the text
		window_text_stale_color = 0x777777, --the color of any logs pulled from history log (read from disk, ie from previous state/session)
		window_text_selected_color = 0x000000, --the color of highlighted text
		window_input_box_color = 0x444444, --the color of the bg box behind the input text box
		window_button_normal_color = 0xffffff, --the color of most ordinary buttons
		window_button_highlight_color = 0xffd700, --the color of a button being moused over
		window_alpha = 1,
		window_x = 50,
		window_y = 50,
		window_w = 1000,
		window_h = 600,
		window_font_name = "fonts/font_bitstream_vera_mono",
		window_font_size = 10,
		window_blur_alpha = 0.75,
		window_bg_color = 0x000000,
		window_bg_alpha = 0.5,
		window_caret_string = "|",
		window_caret_color = 0xffffff,
		window_caret_alpha = 0.75,
		window_prompt_string = "> ",
		window_prompt_color = 0xffffff,
		window_prompt_alpha = 0.66
	}
	Console.settings = table.deep_map_copy(Console.default_settings)
	Console.settings_sort = {
		"safe_mode",
		"input_log_enabled",
		"output_log_enabled",
		"log_buffer_enabled",
		"window_scrollbar_lock_enabled",
		"window_scroll_direction_reversed",
		"window_text_normal_color",
		"window_text_highlight_color",
		"window_text_selected_color",
		"window_text_stale_color",
		"window_input_box_color",
		"window_button_normal_color",
		"window_button_highlight_color",
		"window_alpha",
		"window_x",
		"window_y",
		"window_w",
		"window_h",
		"window_font_name",
		"window_font_size",
		"window_blur_alpha",
		"window_bg_color",
		"window_bg_alpha",
		"window_caret_string",
		"window_caret_color",
		"window_caret_alpha",
		"window_prompt_string",
		"window_prompt_color",
		"window_prompt_alpha"
	}
	
	Console.type_data = {
		--base data types
		--todo allow changing through settings
		["function"] = {
			color = Color(0.5,1,1)
		},
		["string"] = {
			color = Color(0.5,0.5,0.5)
		},
		["number"] = {
			color = Color(0.66,1,0)
		},
		["table"] = {
			color = Color(1,1,0)
		},
		["boolean"] = {
			color = Color(0.3,0.3,1)
		},
		["userdata"] = {
			color = Color(1,0.3,0.3)
		},
		["thread"] = {
			color = Color(1,1,0.5)
		},
		["nil"] = {
			color = Color(0.3,0.3,0.3)
		}
	}
	Console._log_buffer_timer = 0
	Console._output_log = {}
	Console._input_log = {
	--[[ ex.
		[1] = {
			input = "/echo hello -p",
			saved_input = nil,
			func = function 0xd3adb33f --from loadstring
		},
		[2] = {
			raw_input = "//", --shortcut for repeat previous execution
			saved_input = "/echo hello -p",
			func = function 0xd3adb33f --same direct reference to previous function
		},
		[3] = {
			raw_input = "/print $hello",
			saved_input = nil,
			func = function 0x1234567 --different direct referencce
		},
		[4] = {
			raw_input = "///", --shortcut for re-interpret previous input and execute (eg. if the value of a var has changed since previous execution)
			saved_input = "/print $hello",
			re-evaluate = true, --cue loadstring of input
			func = new function --result of loadstring
		},
		[5] = {
			raw_input = "/set $hello 69", --set var $hello to 69
			func = new function --result of loadstring
		}
		--]]
	}
	Console._registered_commands = {}
	
	Console._user_vars = {
	--[[
		--number-based vars are reserved for system use, for when history log outputs 
		hello = 1345136
		
		
	--]]
	}
	Console._buffers = {
		input_log = {},
		output_log = {}
	}
	Console.VAR_PREFIX = "$"
	
	--placeholder values for thinngs that will be loaded later
	Console._colorpicker = nil
	Console._is_font_asset_load_done = nil --if font is loaded
end

do --load ini parser
	local f,e = blt.vm.loadfile(Console._mod_path .. "utils/LIP.lua")
	local lip
	if e then 
		log("[Horizon Indicator in HUD] ERROR: Failed loading LIP module. Try re-installing BeardLib if this error persists.")
	elseif f then 
		lip = f()
	end
	if lip then 
		Console._lip = lip
	end
end



--utils

function Console.table_concat(tbl,div) --the main difference from table.concat is that this stringifies the values
	div = tostring(div or ",")
	if type(tbl) ~= "table" then 
		return "(concat error: non-table value)"
	end
	local str
	for k,v in pairs(tbl) do
		str = str and (str .. div .. tostring(v)) or tostring(v)
	end
	return str or ""
end

function Console.string_trim_leading_spaces(s)
	local trim_start,trim_end = string.find(s,"^%s")
	if trim_end then 
		if trim_end <= string.len(s) then
			return string.sub(s,trim_end + 1),true
		else
			return "",true
		end
	else
		return s,false
	end
end



--loggers

function Console:Log(info,params)
	info = tostring(info)
	log("CONSOLE: " .. info)
	self:AddToOutputLog(info)
end
_G.Log = callback(Console,Console,"Log")
Console.log = Console.Log

function Console:Print(...)
	self:Log(self.table_concat({...}," "))
end
_G.Print = callback(Console,Console,"Print")

function Console:LogTable(obj,max_amount)
--generally best used to log all of the properties of a Class:
--functions;
--and values, such as numbers, strings, tables, etc.

	
	--i don't really know how else to do this
--todo save this as a global to Console so that i can create and delete examples but save their references
	local t = Application:time()
	local timeout = 5
	if not obj then 
		Console:Log("Nil obj to argument1 [" .. tostring(obj) .. "]",{color = Color.red})
		return
	end
	local i = type(max_amount) == "number" and max_amount and 0
	max_amount = max_amount and type(max_amount) == "number" or 0
	Console._failsafe = false
	while not Console._failsafe do 
		if Application:time() > t + timeout then
			Console._failsafe = true
		end
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
				for type_name,data in pairs(Console.type_data) do 
					if data.example then
						local a1 = getmetatable(data.example)
						local a2 = a1 and a1.__index
						local b1 = getmetatable(v)
						local b2 = b1 and b1.__index
						if (b2 and a2) and (b2 == a2) then
							data_type = type_name
							break
						end
					end
				end
			end
			
			Console:Log("[" .. tostring(k) .. "] : [" .. tostring(v) .. "]",{color = Console.type_data[data_type] and Console.type_data[data_type].color or Color(1,0.3,0.3)})
		end
		Console._failsafe = true --process can be stopped with "/stop" if log turns out to be recursive or too long in general
	end
	Console._failsafe = false
end
_G.logall = callback(Console,Console,"LogTable")


--core functionality

function Console:Update(updater_source,t,dt)
	if self.settings.log_buffer_enabled then 
		local buffer_timer = self._log_buffer_timer
		buffer_timer = buffer_timer - dt
		if buffer_timer < 0 then 
			buffer_timer = self.settings.log_buffer_interval
			self:FlushInputLogBuffer()
			self:FlushOutputLogBuffer()
		end
	end
end

function Console:InterpretCommand(raw_cmd_string)
	self:Log("> " .. raw_cmd_string)
	local cmd_params = {}
	local cmd_string = raw_cmd_string
--	local cmd_string = self.string_trim_leading_spaces(raw_cmd_string)
	local cmd_name = string.match(cmd_string,"[^%s]*")--[%a%s]+")
	
	if not cmd_name or cmd_name == "" then
		return
	elseif not self._registered_commands[cmd_name] then 
		self:Log("/" .. cmd_name .. ": No such command found.")
		return
	end
	
	
	--find quotes and ESCAPE THEM
	local escape_set_characters = {
		"\"",
		'\''
	}
	local _pair_chars = {}
	local _pair_data = {}
	for _,pair_char in pairs(escape_set_characters) do 
		local pair_start,pair_finish = string.find(cmd_string,pair_char .. "[^" .. pair_char .. "]*" .. pair_char)
		if pair_start then 
			table.insert(_pair_chars,#_pair_chars+1,
				{
					character = pair_char,
					start = pair_start,
					finish = pair_finish
				}
			)
		end
	end
	local has_quotes = #_pair_chars > 0
	local _pairs = {}
	if has_quotes then 
		table.sort(_pair_chars,function(a,b)
			return a.start < b.start
		end)
		
		for _,v in ipairs(_pair_chars) do 
			local pair_char = v.character
			local exit_pair
			local index = 1
			repeat
				local a,b = string.find(cmd_string,pair_char .. "[^" .. pair_char .. "]*" .. pair_char,index+1)
				if a == b then 
					exit_pair = true
				else
					table.insert(_pairs,1,{
						character = pair_char,
						start = a,
						finish = b
					})
					index = b
				end
			until exit_pair
		end
		for i,pair_data in ipairs(_pairs) do 
			local start = pair_data.start
			local finish = pair_data.finish
			local orig_string = string.sub(cmd_string,start,finish)
			local sub_string = "DCCQUOTECHAR" .. i
			pair_data.substitution_string = sub_string
			pair_data.original_string = orig_string
			cmd_string = string.sub(cmd_string,1,start-1) .. sub_string .. string.sub(cmd_string,finish+1)
		end
		
	end
	
	local first_occurrence
	for word in string.gmatch(cmd_string,"%-[%a%p]+[^%-]*") do 
		local param_start,param_finish = string.find(word,"%-[%a%p]+")
		local param_name = string.sub(word,param_start+1,param_finish)
		if not first_occurrence then
			first_occurrence = param_start
		end
		local _word = string.sub(word,param_finish+1)
		--[[
		local params = {}
		for arg in string.gmatch(_word,"[^%s]*") do 
			if arg ~= "" then
				Print("New arg [" .. tostring(arg) .. "]")
				table.insert(params,#params+1,arg)
			end
		end
		cmd_params[param_name] = params
		--]]
		local param = string.match(_word,"[^%s]+")
		cmd_params[param_name] = param
	end
	

	
	local args_string
	if first_occurrence then
		args_string = string.sub(cmd_string,string.len(cmd_name),first_occurrence)
		Log(args_string)
	end
	if has_quotes then
		for i=#_pairs,1,-1 do
			local pair_data = _pairs[i]
			for param,param in pairs(cmd_params) do 
				local new_param,num_done = string.gsub(param,pair_data.substitution_string,pair_data.original_string)
				if num_done > 0 then
					cmd_params[param] = new_param
				end
				local new_param_name,num_done = string.gsub(param,pair_data.substitution_string,pair_data.original_string)
				if num_done > 0 then 
					cmd_params[new_param_name] = param
					cmd_params[param] = nil
				end
			end
		--[[
		for param_name,params in pairs(cmd_params) do 
			for param_key,arg in pairs(params) do 
				for i=#_pairs,1,-1 do
					local pair_data = _pairs[i]
					local new_arg,num_done = string.gsub(arg,pair_data.substitution_string,pair_data.original_string)
					if num_done > 0 then 
						params[param_key] = new_arg
--						table.remove(_pairs,i)
					end
					local new_param_name,num_done = string.gsub(param_name,pair_data.substitution_string,pair_data.original_string)
					if num_done > 0 then 
						cmd_params[new_param_name] = params
						cmd_params[param_name] = nil
--						table.remove(_pairs,i)
					end
				end
			end
			--]]
		end
		
		for i=#_pairs,1,-1 do
			local pair_data = _pairs[i]
			local new_string,num_done = string.gsub(cmd_string,pair_data.substitution_string,pair_data.original_string)
			if num_done > 0 then
				cmd_string = new_string
--				table.remove(_pairs,i)
			end
		end
	
	end
	
--[[	
	Print("cmd name",cmd_name)
	Print("cmd string",cmd_string)
	Print("raw_cmd_string",raw_cmd_string)
	logall(cmd_params)
	Log("--")
	do return end
--]]	
	
	
	local command_data = self._registered_commands[cmd_name]
	if command_data.func then 
		command_data.func(cmd_params,args_string)
	elseif command_data.str then 
		local func,err = loadstring(command_data.str)
		if func then
			command_data.func = func
			return pcall(func,cmd_params,args_string)
		elseif err then
			self:Log(err)
		end
	end
	Log(cmd_name)
end

function Console:callback_confirm_text(dialog_instance,text)
	if string.sub(text,1,1) == "/" then 
		local input_log = self._input_log
		if text == "//" then 
			if #input_log > 0 then
				local data = input_log[#input_log]
				text = data.input or data.raw_input
				--if data.func then 
				
				--end
			else
				self:Log("Error: No command history!")
			end
		else
			self:InterpretCommand(string.sub(text,2))
		end
	elseif text ~= "" then
		self:Log("> " .. text)
		return self:InterpretInput(text)
	end
end

function Console:InterpretInput(raw_string)
--	local s = string.match(raw_string,"[^%s]*.*")
	local s = raw_string
	local func,err = loadstring(s)
	if err then 
		self:Log("Error loading chunk:")
		self:Log(err)
	elseif func then 
		local result = pcall(func)
	end
	self:AddToInputLog(s)
--	self:AddToOutputLog(result)
	local color_data -- = {}
	return s,color_data --colors here
end

--management


function Console:RegisterCommand(id,data)
	if not id then
		self:Log("ERROR: RegisterCommand(" .. tostring(id)..") failed: Bad command name",{color = Color.red}) 
		return
	elseif type(data) ~= "table" then 
		self:Log("ERROR: RegisterCommand(" .. tostring(id)..") failed: Bad command data",{color = Color.red}) 
		return
	end
	self._registered_commands[id] = data
end


--front

function Console:ExampleFunction(params,args)
	for title,param in pairs(args) do 
		
	end
end

--commands

function Console:cmd_help(subcmd,arg) --not yet implemented
	if subcmd then 
		local cmd_data = self._registered_commands[subcmd] 
		if cmd_data then 
			self:Log("/" .. cmd_data.subcmd)
			self:Log(cmd_data.desc)
			self:Log(cmd_data.manual)
			if cmd_data.parameters then 
				for k,v in pairs( cmd_data.parameters ) do 
					self:Log("-" .. k .. " " .. tostring(v.arg_desc))
					self:Log(tostring(v.short_desc))
				end
			end
		end
	else
		for k,v in pairs(self._registered_commands) do 
			if not v.hidden then
				self:Log("/" .. tostring(k))
				self:Log(v.desc)
				self:Log("")
			end
		end
	end
end

function Console:cmd_weaponname(params,name)
	params = type(params) == "table" and params or {}
	local results = {}
	
	local category = params.category
	local slot = tonumber(params.slot)	Log("category [" .. tostring(category) .. "]")
	Log("slot [" .. tostring(slot) .. "]")
	logall(params)
	
	local function check_weapon(data)
		if slot then 
			if data.use_data and data.use_data.selection_index == slot then 
				--found
			else
				return false
			end
		end
		local localized_name = data.name_id and managers.localization:text(data.name_id)
		if name then
			if localized_name and string.find(string.lower(localized_name),string.lower(name)) or string.find(string.lower(weapon_id),string.lower(name)) then
				--found
			else
				return false
			end
		end
		if category then
			if data.categories and table.contains(data.categories,category) then
				--found
			else
				return false
			end
		end
		self:Log(tostring(weapon_id) .. " / " .. tostring(localized_name or "UNKNOWN"))
		return true
	end
	local search_feedback_str = "--- Searching for"
	if name and name ~= "" then 
		search_feedback_str = search_feedback_str .. ": [" .. tostring(name) .. "]"
	else
		search_feedback_str = search_feedback_str .. " all weapons"
	end
	if category then 
		search_feedback_str = search_feedback_str .. " with category [" .. tostring(category) .. "]"
	end
	if slot then
		search_feedback_str = search_feedback_str .. " in slot [" .. tostring(slot) .. "]"
	end
	search_feedback_str = search_feedback_str .. "..."
	self:Log(search_feedback_str)
	for weapon_id,data in pairs(tweak_data.weapon) do 
		if type(data) == "table" then
			if check_weapon(data) then
				table.insert(results,weapon_id)
			end
		end
	end
	self:Log("---Search ended.")
	return results
end

function Console:cmd_partname(params,name)
	params = type(params) == "table" and params or {}
	local results = {}
	local _type = params.type
	local weapon_id = params.weapon_id or params.weapon
	
	local search_feedback_str = "--- Searching for"
	if name and name ~= "" then 
		search_feedback_str = search_feedback_str .. " part: [" .. tostring(name) .. "]"
	else
		search_feedback_str = search_feedback_str .. " all parts"
	end
	if _type then 
		search_feedback_str = search_feedback_str .. " of attachment type [" .. tostring(_type) .. "]"
	end
	if weapon_id then 
		search_feedback_str = search_feedback_str .. " usable on weapon with weapon_id [" .. tostring(weapon_id) .. "]"
	end
	search_feedback_str = search_feedback_str .. "..."
	self:Log(search_feedback_str)
	
	local function check_part(part_id,part_data)
		local localized_name = part_data.name_id and managers.localization:text(part_data.name_id)
		
		if _type and _type ~= part_data.type then
			return false
		else
			if name then 
				if localized_name and string.find(string.lower(localized_name),string.lower(name)) then 
					--found
				elseif string.find(string.lower(part_id),string.lower(name)) then 
					--found
				else
					return false
				end
			end
			self:Log(tostring(part_id) .. " / " .. tostring(localized_name or "UNKNOWN"))
			return true
		end
	end
	if weapon_id then
		local bm_id = managers.weapon_factory:get_factory_id_by_weapon_id(weapon_id)
		local bm_weapon_data = bm_id and tweak_data.weapon.factory[bm_id]
		if bm_weapon_data.uses_parts then
			for _,part_id in pairs(bm_weapon_data.uses_parts) do 
				local data = tweak_data.weapon.factory.parts[part_id]
				if data then 
					if check_part(part_id,data) then
						table.insert(results,part_id)
					end
				end
			end
		end
	else
		for part_id,data in pairs(tweak_data.weapon.factory.parts) do 
			if check_part(part_id,data) then
				table.insert(results,part_id)
			end
		end
	end
	
	self:Log("---Search ended.")
	return results
end


	--not yet implemented
	
function Console:cmd_echo(s)
	
end

function Console:SetUserVar(id,val)
	if string.sub(tostring(val),1,1) == self.VAR_PREFIX then 
		val = self:GetUserVar(val)
	end
	self:Log(val)
	self:_SetUserVar(id,val)
end

function Console:_SetUserVar(id,value)
	self._user_vars[id] = value
end

function Console:GetUserVar(...)
	for _,id in pairs({...}) do 
		self:Log(self.VAR_PREFIX .. tostring(id) .. " " .. tostring(self._user_vars[id]))
	end
end



--colorpicker stuff
function Console:GetPalettes()
	local palettes = {}
	for i,col_str in ipairs(self.palettes) do 
		palettes[i] = Color(col_str)
	end
	return palettes
end

function Console:GetDefaultPalettes()
	local palettes = {}
	for i,col_str in ipairs(self.default_palettes) do 
		palettes[i] = Color(col_str)
	end
	return palettes
end

function Console:SetPalettes(palettes)
	for i,color in ipairs(palettes) do 
		self.palettes[i] = ColorPicker.color_to_hex(color)
	end
end

function Console:callback_colorpicker_done(setting,color,palettes,success)

	self:SetPalettes(palettes)
	
	if success then 
		self.settings[tostring(setting)] = tonumber("0x" .. ColorPicker.color_to_hex(color))
		
		self:SaveSettings()
	end
end


--ui

function Console:CreateConsoleWindow()
	self:Log("Creating console window")
	self.dialog_data = {
		id = "ConsoleWindow",
		title = "console title",
		text = "text goes here",
		history_log = self._history_log,
		console_settings = self.settings,
		input_log = self._input_log,
		output_log = self._output_log,
		confirm_text_callback = callback(self,self,"callback_confirm_text"),
		save_settings_callback = callback(self,self,"SaveSettings"),
		font_asset_load_done = self._is_font_asset_load_done,
		button_list = {
			{
				text = "button text",
				callback_func = function()
					log("back button")
				end,
				cancel_button = true
			}
		}
	}
	self._window_instance = ConsoleModDialog:new(managers.system_menu,self.dialog_data)
	
--	managers.system_menu:_show_class(self.dialog_data,managers.system_menu.GENERIC_DIALOG_CLASS,ConsoleModDialog,true)
end

function Console:ShowConsoleWindow()
	managers.system_menu:_show_instance(self._window_instance,true)
--	if Console._window_instance then 
--	else
--		Console:CreateConsoleWindow()
--	end
end

function Console:HideConsoleWindow()
	self._window_instance:hide()
end

function Console:ToggleConsoleWindow()
	local state = not self._window_instance.is_active
	if state then 
		self:ShowConsoleWindow()
	else
		self:HideConsoleWindow()
	end
end


--i/o
function Console:SaveInputLog()
	local file = io.open(self._input_log_file_path,"w+")
	if file then
		file:write(self._input_log)
		file:close()
	end
end

function Console:LoadInputLog()
	local file = io.open(self._input_log_file_path,"r")
	if file then
		local load_chunks_on_read = false
		local i = 0
		for line in file:lines() do 
			i = i + 1
			self._input_log[i] = {
				input = line,
				raw_input = nil,
				saved_input = nil,
				func = nil
			}
			
			if load_chunks_on_read then --probably not necessary since loadstring is kinda heavy
				local func,err = loadstring(line)
				if func then 
					self._input_log[i].func = func
				elseif err then
					--silent fail- if these are logged, the output log would probably balloon in size
					--add errors to table internally?
				end
			end
		end
	end
end

function Console:AddToInputLog(data)
	table.insert(self._input_log,#self._input_log+1,data)
	if self.settings.input_log_enabled then 
		self:WriteToInputLog(data.raw_input or data.input,false)
	end
end

function Console:WriteToInputLog(s,force) --append to log
	if s then
		local buffer_enabled = self.settings.log_buffer_enabled
		if force or not buffer_enabled then
			--do it write now (haha)
			local file = io.open(self._input_log_file_path,"a")
			if file then
				file:write("\n" .. s)
				file:close()
			end
		else
			--queue writing it to a "buffer" and flush the buffer at regular intervals
			table.insert(self._buffers.input_log,1,s)
		end
	end
end

function Console:FlushInputLogBuffer()
	local buffer_count = #self._buffers.input_log
	if buffer_count > 0 then
		local file = io.open(self._input_log_file_path,"a")
		for i=buffer_count,1,-1 do 
			local s = table.remove(self._buffers.input_log,i)
			file:write("\n" .. s)
		end
		file:flush()
		file:close()
	end
end


function Console:SaveOutputLog() --save full log directly
	local file = io.open(self._output_log_file_path,"w+")
	if file then
		file:write(self._output_log)
		file:close()
	end
end

function Console:LoadOutputLog() --load from output
	local file = io.open(self._output_log_file_path,"r")
	if file then
		local i = 0
		for line in file:lines() do 
			i = i + 1
			self._output_log[i] = line
		end
	end
end

function Console:AddToOutputLog(s)
	table.insert(self._output_log,#self._output_log+1,s)
	if self.settings.output_log_enabled then 
		self:WriteToOutputLog(s,false)
	end
end

function Console:WriteToOutputLog(s,force)
	local buffer_enabled = self.settings.log_buffer_enabled
	if force or not buffer_enabled then
		local file = io.open(self._output_log_file_path,"a")
		if file then
			file:write("\n" .. s)
			file:close()
		end
	else
		table.insert(self._buffers.output_log,1,s)
	end
end

function Console:FlushOutputLogBuffer()
	local buffer_count = #self._buffers.output_log
	if buffer_count > 0 then
		local file = io.open(self._output_log_file_path,"a")
		for i=buffer_count,1,-1 do 
			local s = table.remove(self._buffers.output_log,i)
			file:write("\n" .. s)
		end
		file:flush()
		file:close()
	end
end


function Console:LoadSettings()
	if SystemFS:exists( Application:nice_path(self._save_path,true) ) then 
		local config_from_ini = self._lip.load(self._save_path)
		if config_from_ini then 
			if config_from_ini.Config then 
				for k,v in pairs(config_from_ini.Config) do
					if self.color_setting_keys[k] then
						self.settings[k] = string.format("%06x",v)
					else
						self.settings[k] = v
					end
				end
			end
			if config_from_ini.Palettes then 
				for i,v in ipairs(config_from_ini.Palettes) do 
					self.palettes[i] = string.format("%06x",v)
				end
			end
		end
	else
		self:SaveSettings()
	end
end

function Console:SaveSettings()
	local palettes = {}
	for i,v in ipairs(self.palettes) do
		--one unfortunate limitation of LIP is that it has a very limited ability to infer data types from regular ol' strings
		--only the primitives Bool, Number (Float/Int), and String are supported within a given table
		--and LIP does not recognize hex numbers properly-
		--if the value start with a number character, it is interpreted as a regular decimal number
		--so saving the hex string 000088 would work fine, but the hex string "000088" would be loaded as the decimal number "88"
		--could also solve this by wrapping them in quotation marks or other punctuation like so:
--				palettes[i] = "\"" .. v .. "\""
--				self.palettes[i] = string.gsub(v,"%p","")
		--or saving the number in decimal form to preserve its value:
			--tonumber("0x" .. v)
		--it's not really a better solution, just a different one
		
		palettes[i] = "0x" .. v --tonumber("0x" .. v)
		
	end
	self._lip.save(self._save_path,{Config = self.settings,Palettes=palettes},self.settings_sort)
end


--asset loading


function Console:AddFonts()
	local window_font_name = self.settings.window_font_name
	local file_path = self._mod_path .. "assets/" .. tostring(window_font_name)
	
	local font_path = window_font_name
	local font_ids = Idstring("font")
	local texture_ids = Idstring("texture")
	local dyn_pkg = DynamicResourceManager.DYN_RESOURCES_PACKAGE
	
	local file_path_ids = Idstring(file_path)
	
	if DB:has(font_ids, font_path) then 
		self:Log("Font " .. font_path .. " is verified.")
	else
		--assume that if the .font is not loaded, then the .texture is not either (both are needed anyway)
		self:Log("Font " .. font_path .. " is not created!")
		BLT.AssetManager:CreateEntry(Idstring(font_path),font_ids,file_path .. ".font")
		BLT.AssetManager:CreateEntry(Idstring(font_path),texture_ids,file_path .. ".texture")
	end
end

function Console:LoadFonts()
	local window_font_name = self.settings.window_font_name
	local file_path = self._mod_path .. "assets/" .. tostring(window_font_name)
	
	local font_path = window_font_name
	local font_path_ids = Idstring(font_path)
	local font_ids = Idstring("font")
	local texture_ids = Idstring("texture")
	local dyn_pkg = DynamicResourceManager.DYN_RESOURCES_PACKAGE

	-- [[
	
	if managers.dyn_resource:is_resource_ready(font_ids,font_path_ids,dyn_pkg) then 
		self:Log("Resource ready " .. tostring(font_path))
		self._is_font_asset_load_done = true
	else
		self._is_font_asset_load_done = false
		
		self:Log("Resource not ready " .. tostring(font_path))
		self:Log("Starting load: " .. tostring(file_path))
--		Console:Log("CreateConsoleWindow() Font [" .. tostring(font_name) .. "] is not yet loaded! Delaying console window creation.")
--		return
		
		local asset_loading_checklist = {
			texture_ids,
			font_ids
		}
		
		local done_font = false
		local done_texture = false
		local function done_loading_cb(done,resource_type_ids,resource_ids)
			if done then 
				self:Log("Completed manual asset loading for " .. tostring(resource_type_ids) .. " " .. tostring(resource_ids))
--				self._is_font_asset_load_done = true
				if resource_ids == font_path_ids then
					local i = table.index_of(asset_loading_checklist,resource_type_ids)
					if i then
						table.remove(asset_loading_checklist,i)
					end
					if #asset_loading_checklist == 0 then 
						self._is_font_asset_load_done = true
						
						if self._window_instance then
							self._window_instance:callback_on_delayed_asset_load(resource_ids)
						end
					end
				end
				
			else
				self:Log("Error: not done???")
			end
		end
		
		managers.dyn_resource:load(font_ids,font_path_ids,dyn_pkg,done_loading_cb)
		managers.dyn_resource:load(texture_ids,font_path_ids,dyn_pkg,done_loading_cb)
	end
	--]]
end

--menu hooks

Hooks:Register("ConsoleMod_RegisterCommands")

Hooks:Add("MenuManagerInitialize", "dcc_menumanager_init", function(menu_manager)
--	Console:LoadSettings() --temp disabled; work from default settings for now
	Console:AddFonts()
	Console:LoadFonts()
	
	if not Console.settings.safe_mode then 
		if Console.settings.output_log_enabled then 
			Console:LoadOutputLog()
		end
		if Console.settings.input_log_enabled then 
			Console:LoadInputLog()
		end
	end
	MenuCallbackHandler.callback_dcc_console_window_focus = function(self)
		Console:ToggleConsoleWindow()
	end
	MenuCallbackHandler.callback_on_console_window_closed = function(self) end --not used
	MenuCallbackHandler.callback_on_console_window_closed = function(self) end --not used
	
	
	
	Console:RegisterCommand("partname",{
		str = nil,
		desc = "Search for a part by localized name/description, internal name/description, internal id, or blackmarket id.",
		manual = "Usage: /partname [search key]\n\nParameters:\n-type [attachment type]\n-weapon [weapon id]",
		parameters = {
			type = {
				arg_desc = "[attachment type]",
				short_desc = "The attachment type to filter for, eg. silencer, barrel, stock, etc. Must be exact type match."
			},
			weapon = {
				arg_desc = "[weapon]",
				short_desc = "The weapon id to filter for, eg. m134, flamethrower, saw, m1911, or new_m4. If supplied, partname will only display attachments that can be applied to this weapon. Must be exact weapon_id match."
			}
		},
		func = callback(Console,Console,"cmd_partname")
	})
	Console:RegisterCommand("weaponname",{
		str = nil,
		desc = "Search for a weapon by localized name/description, internal name/description, internal id, or blackmarket id.",
		manual = "Usage: /weaponname [search key]",
		parameters = {
			category = {
				arg_desc = "[category]",
				short_desc = "The weapon category to filter for, eg. shotgun, smg, lmg, etc. Must be exact category match."
			},
			slot = {
				arg_desc = "[weapon slot]",
				short_desc = "The weapon slot number to filter for, eg. 1, 2, etc. Must be exact slot match."
			}
		},
		func = callback(Console,Console,"cmd_weaponname")
	})
	--Console:RegisterCommand("weaponinfo")
	Hooks:Call("ConsoleMod_RegisterCommands",Console)
	
	
	Console:CreateConsoleWindow()

	MenuHelper:LoadFromJsonFile(Console._menu_path, Console, Console.settings)
end)


--[[ console menu node
ConsoleMenuNode = ConsoleMenuNode or class()
function ConsoleMenuNode:init(parent_menu)
	local new_node = {
		_meta = "node",
		name = "console_window_node",
		back_callback = "callback_on_console_window_closed",
		menu_components = "console_menu_node",
		scene_state = "",
		[1] = {
			["_meta"] = "default_item",
			["name"] = "back"
		}
	}
	table.insert(parent_menu,new_node)
end

function Console:callback_menucomponent_create(menu_component_manager)
	menu_component_manager._active_components.
end
--]]

Hooks:Add("MenuManagerSetupCustomMenus", "dcc_MenuManagerSetupCustomMenus", function(menu_manager, nodes)
--	Console._menu_node = MenuHelper:NewMenu(Console.console_window_menu_id)
end)
Hooks:Add("MenuManagerPopulateCustomMenus", "dcc_MenuManagerPopulateCustomMenus", function(menu_manager, nodes)
--[[
	nodes[Console.console_window_menu_id] = MenuHelper:BuildMenu(Console.console_window_menu_id,{
		area_bg = "none",
		back_callback = MenuCallbackHandler.callback_on_console_window_closed,
		focus_changed_callback = "callback_dcc_console_window_focus"
	})
	--]]
end)

Hooks:Add("MenuManagerBuildCustomMenus", "dcc_MenuManagerBuildCustomMenus", function( menu_manager, nodes )
end)

--[[
--overwrite to prevent blt keybinds from executing during typing?
Hooks:Add("MenuUpdate", "Base_Keybinds_MenuUpdate", function(t, dt)
	BLT.Keybinds:update(t, dt, BLTKeybind.StateMenu)
end)

Hooks:Add("GameSetupUpdate", "Base_Keybinds_GameStateUpdate", function(t, dt)
	BLT.Keybinds:update(t, dt, BLTKeybind.StateGame)
end)

--]]

--updater hooks
Hooks:Add("MenuUpdate", "dcc_update_menu", callback(Console,Console,"Update","MenuUpdate"))
Hooks:Add("GameSetupUpdate", "dcc_update_gamesetup", callback(Console,Console,"Update","GameSetupUpdate"))



--deprecated/not implemented
local function dummy() end

local deprecated_func_list = {
"AchievementsDisabled",
"Add_Popup",
"Remove_Popup",
"update_hud_popups",
"cmd_godmode",
"RegisterCommand",
"GetEscBehavior",
"GetKeyboardRegion",
"GetFontSize",
"GetScrollSpeed",
"GetPrintMode",
"SaveKeybinds",
"LoadKeybinds",
"Load",
"Save",
"searchall",
"logall",
"Log",
"new_log_line",
"should_blt_log",
"angle_between_pos",
"c_log",
"t_log",
"t_log_2",
"cmd_tracker",
"CreateTracker",
"GetTrackerElementByName",
"RegisterTrackerUpdater",
"SetTrackerData",
"SetTrackerValue",
"SetTrackerColor",
"SetTrackerColorRGB",
"SetTrackerXY",
"cmd_unit",
"SetUnitInfo",
"RemoveTracker",
"RegisterPersistScript",
"RemovePersistScript",
"AdventureInput",
"cmd_adventure",
"cmd_unbind",
"cmd_unbindall",
"cmd_bind",
"AddBind",
"cmd_bindid",
"cmd_help",
"cmd_contact",
"cmd_about",
"cmd_info",
"cmd_epoch",
"cmd_runtime",
"cmd_time",
"cmd_date",
"cmd_whisper",
"cmd_say",
"cmd_dofile",
"cmd_quit",
"cmd_pos",
"cmd_sound",
"cmd_rot",
"cmd_teleport",
"cmd_pause",
"cmd_forcestart",
"cmd_restart",
"cmd_fov",
"cmd_sens",
"cmd_sens_aim",
"cmd_ping",
"cmd_getinfo",
"cmd_writetodisk",
"cmd_stop",
"cmd_state",
"cmd_skillname",
"cmd_skillinfo",
"cmd_gotonav",
"cmd_editnav",
"cmd_bltmods",
"cmd_weaponname",
"cmd_partname",
"update",
"update_persist_scripts",
"update_hud",
"update_custom_keybinds",
"update_restart_timer",
"update_scroll",
"upd_caret",
"held",
"_shift",
"_ctrl",
"_alt",
"mouse_moved",
"mouse_pressed",
"mouse_released",
"mouse_clicked",
"mouse_double_clicked",
"_scrollbar_held",
"_set_scrollbar_held",
"_set_scrollbar_released",
"enter_text",
"key_press",
"update_key_down",
"key_release",
"refresh_scroll_handle",
"esc_key_callback",
"enter_key_callback",
"ToggleConsoleFocus",
"ClearConsole",
"GetFwdRay",
"SetFwdRayUnit",
"GetTaggedPosition",
"GetTaggedUnit",
"CreateCameraDebugs",
"GetCharList",
"BuildCharList",
"split_two",
"split_cmd",
"split_parse",
"string_excise",
"InterpretInput",
"evaluate",
"TagPosition",
"GenerateHitboxes",
"ResetSettings",
"_create_commandprompt"
}
for _,name in pairs(deprecated_func_list) do 
	Console[name] = Console[name] or dummy
end