--[[


******************* Feature list todo: ******************* 

- straighten out Log/Print/output call flow
	- different levels of logging
	print/log behavior option checkboxes
	
- session pref with existing vars
tab key autocomplete
- display behavior to console for Log()
- rounded corners in ConsoleModDialog
	- center submit button and create its own subpanel
	- increase Console header size
- ConsoleModDialog scroll button click input repeat
- 

******************* Secondary feature todo ******************* 


- batch file folder system in saves
	autoexec batch-style files
- option to de-focus the console and keep it open while playing without hiding it
- "/" key shortcut to open console window

- mouse-selectable output text
- mouse-selectable input text
- preview history in dialog ui
	show number of history steps?
- "undo" steps history
- limit number/size of input/output logs (enforced on save and load)
- save scrollbar position to session "settings"
- separate session "settings" from normal configuration settings?
- allow changing type colors through settings


******************* Commands todo *******************

- echo/print - print result or results to console
	echo should be mainly for vars
	
- setvar/session var business
	$ var values (saved between sessions)
	@ temp var values (overrides normal vars, not saved)

- // executes previous stored loadstring function
- /// re-evaluates and executes previous stored input

- /clear command to clear logs


- warning/text-based confirm prompt eg. when a query is expected to have lots of results


*******************  Bug list [high priority] ******************* 

- [Console] history navigation is unreliable
	commands are not shown in input history

- [ConsoleModDialog] scroll function
	--lock scrollbar (disable autoscroll on new lines) not working
	--reverse scroll direction option needs to be redone and applied more broadly
	- restrict the vertical size during resizing so that it can't be smaller than all of the scroll buttons
	shrink the scroll bar during resizing to a percentage of the current window height
- resizing is currently disabled


*******************  Bug list [low priority] ******************* 

- [ConsoleModDialog] separate callbacks in create_gui into their own functions
- [ConsoleModDialog] color range is broken on adding new history text
	-solution: save number of stored input and output log lines to color range data, re-apply when appending to the console output 

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
		"window_frame_color",
		"window_bg_color",
		"window_caret_color",
		"window_prompt_color",
		"style_data_color_function",
		"style_data_color_string",
		"style_data_color_number",
		"style_data_color_table",
		"style_data_color_boolean",
		"style_data_color_nil",
		"style_data_color_thread",
		"style_data_color_userdata",
		"style_data_color_misc",
	}
	Console.palettes = table.deep_map_copy(Console.default_palettes)
	Console.default_settings = {
		safe_mode = false,
		console_params_guessing_enabled = true,
		input_log_enabled = true,
		output_log_enabled = false,
		log_buffer_enabled = true,
		log_buffer_interval = 10, --seconds between flushes
		style_data_color_function = 0x7fffff,
		style_data_color_string = 0x7f7f7f,
		style_data_color_number = 0xa8ff00,
		style_data_color_table = 0xffff00,
		style_data_color_boolean = 0x4c4cff,
		style_data_color_nil = 0x4c4c4c,
		style_data_color_thread = 0xffff7f,
		style_data_color_userdata = 0xff4c4c,
		style_data_color_misc = 0x888888,
		window_scrollbar_lock_enabled = true,
		window_scroll_direction_reversed = true,
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
		window_frame_color = 0x666666,
		window_frame_alpha = 0.5,
		window_font_name = "fonts/font_bitstream_vera_mono",
		window_font_size = 10,
		window_blur_alpha = 0.75,
		window_bg_color = 0x000000,
		window_bg_alpha = 0.5,
		window_caret_string = "|",
		window_caret_color = 0xffffff,
		window_caret_alpha = 0.75,
		window_prompt_string = "] ",
		window_prompt_color = 0xff0000,
		window_prompt_alpha = 0.66
	}
	Console.settings = table.deep_map_copy(Console.default_settings)
	Console.settings_sort = {
		"safe_mode",
		"input_log_enabled",
		"output_log_enabled",
		"log_buffer_enabled",
		"log_buffer_interval",
		"console_params_guessing_enabled",
		"window_scrollbar_lock_enabled",
		"window_scroll_direction_reversed",
		"window_text_normal_color",
		"window_text_highlight_color",
		"window_text_selected_color",
		"window_text_stale_color",
		"window_input_box_color",
		"window_button_normal_color",
		"window_button_highlight_color",
		"window_frame_color",
		"window_frame_alpha",
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
		"window_prompt_alpha",
		"style_data_color_function",
		"style_data_color_string",
		"style_data_color_number",
		"style_data_color_table",
		"style_data_color_boolean",
		"style_data_color_nil",
		"style_data_color_thread",
		"style_data_color_userdata",
		"style_data_color_misc"
	}
	
	Console.data_type_colors = {
		--base data types
		["function"] = "style_data_color_function",
		["string"] = "style_data_color_string",
		["number"] = "style_data_color_number",
		["table"] = "style_data_color_table",
		["boolean"] = "style_data_color_boolean",
		["userdata"] = "style_data_color_userdata",
		["thread"] = "style_data_color_thread",
		["nil"] = "style_data_color_nil",
		["misc"] = "style_data_color_misc"
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
	Console._operation_timeout = 5
	Console._io_buffer_size = 2^13
	Console._buffers = {
		input_log = {},
		output_log = {}
	}
	Console.VAR_PREFIX = "$"
	Console._is_reading_log = false
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

function Console.hex_number_to_color(n)
	return type(n) == "number" and Color(string.format("%06x",n))
end

--loggers

function Console:Log(info,params)
	info = tostring(info)
	log("CONSOLE: " .. info)
	self:AddToOutputLog(info)
	return info
end
_G.Log = callback(Console,Console,"Log")
Console.log = Console.Log

function Console:Print(...)
	return self:Log(self.table_concat({...}," "))
end
_G.Print = callback(Console,Console,"Print")

function Console:LogTable(obj,max_amount)
--generally best used to log all of the properties of a Class:
--functions;
--and values, such as numbers, strings, tables, etc.

	
	--i don't really know how else to do this
--todo save this as a global to Console so that i can create and delete examples but save their references
	local t = os.clock()
	local timeout = 5
	if not obj then 
		Console:Log("Nil obj to argument1 [" .. tostring(obj) .. "]",{color = Color.red})
		return
	end
	local i = type(max_amount) == "number" and max_amount or 0
	Console._breaker = false
	while not Console._breaker do 
		if t > t + timeout then
			Console._breaker = true
		end
		if i then 
			i = i + 1
			if max_amount and i > max_amount then
				Console:Log("Reached manual log limit " .. tostring(max_amount),{color = Color.yellow})
				return
			end
		end
		for k,v in pairs(obj) do 
		--[[
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
--			Console:Log("[" .. tostring(k) .. "] : [" .. tostring(v) .. "]",{color = Console.type_data[data_type] and Console.type_data[data_type].color or Color(1,0.3,0.3)})
		--]]
			Console:Log("[" .. tostring(k) .. "] : [" .. tostring(v) .. "]")
		end
		Console._breaker = true
	end
	Console._breaker = false
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
	local cmd_string = string.sub(raw_cmd_string,2) --remove forwardslash
	local cmd_name = string.match(cmd_string,"[^%s]*")--[%a%s]+")
	
	if not cmd_name or cmd_name == "" then
		return
	end
	local command_data = self._registered_commands[cmd_name]
	if not command_data then 
		self:Log("/" .. cmd_name .. ": No such command found.")
		return
	end
	local possible_params
	if command_data.parameters then
		if self.settings.console_params_guessing_enabled then 
			possible_params = {}
			for parameter_name,_ in pairs(command_data.parameters) do 
				table.insert(possible_params,parameter_name)
			end
			table.sort(possible_params) --sort possible parameters alphabetically
		end
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
	
	--reduce redundant spaces
	cmd_string = string.gsub(cmd_string,"%s+"," ")
	local params = {}
	local params_start,params_finish = string.find(cmd_string,"[%-][%a%p]+[^%-]*")
	for word in string.gmatch(cmd_string,"%-[%a%p]+[^%-]*") do 
		local _word = string.sub(word,params_start+1)
		
		local param_name = ""
		local param_value = ""
		local param_name_start,param_name_end = string.find(word,"[^%-][^%s]*")
		if param_name_start then
			param_name = string.match(string.sub(word,param_name_start,param_name_end),"[%w%p]+.*")
			param_name = string.reverse(string.match(string.reverse(param_name),"[%w%p]+.*"))
			param_value = string.match(string.sub(word,param_name_end+2),"[%w%p]+.*")
			param_value = string.reverse(string.match(string.reverse(param_value),"[%w%p]+.*"))
		end
		
		if possible_params then
			local confirmed_parameter
			local i_p = table.index_of(possible_params,param_name)
			if i_p then 
				table.remove(possible_params,i_p)
				confirmed_parameter = true
			end
		end
		table.insert(params,#params+1,{name = param_name,value=param_value,confirmed = confirmed_parameter})
	end
	
	--guess the closest match for any parameter eg. -a --> -all
	if possible_params then
		for _,param_data in ipairs(params) do 
			if param_data.confirmed then
				--exact match already exists
			else
				local best_match
				local p = table.deep_map_copy(possible_params)
				for j=1,string.len(param_data.name),1 do 		
					local subs = string.sub(param_data.name,1,j)
					--check a growing substring of the parameter
					for i=#p,1,-1 do
						--against each possible parameter
						local pn = p[i]
						if not string.find(pn,subs) then
							table.remove(p,i)
							break
						end
					end
				end
				if #p > 0 then
					local pn = p[1]
					param_data.name = pn
					param_data.confirmed = true
					table.remove(possible_params, (table.index_of(possible_params,pn)) )
				end
			end
		end
	end
	
	for _,param_data in ipairs(params) do 
		cmd_params[param_data.name] = param_data.value
	end
	
	local args_string
	if params_start then 
		args_string = string.sub(cmd_string,string.len(cmd_name) + 2,params_start-2) --extra index for the space
	else
		args_string = string.sub(cmd_string,string.len(cmd_name) + 2) --extra index for the space
	end
	
	if has_quotes then
		local function replace_orig_subs (str,pair_data)
			local new_str,num_done = string.gsub(str,pair_data.substitution_string,pair_data.original_string)
			if num_done > 0 then
				return new_str,true
			end
			return str,false
		end
		for i=#_pairs,1,-1 do
			local pair_data = _pairs[i]
			for param_name,param_value in pairs(cmd_params) do 
				cmd_params[param_value] = replace_orig_subs(param_value,pair_data)
			end
			
			args_string = replace_orig_subs(args_string,pair_data)
			
		end
		
		for i=#_pairs,1,-1 do
			local pair_data = _pairs[i]
		end
		
	end
	
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
		
		table.insert(self._input_log,#self._input_log+1,{
			raw_input = raw_cmd_string,
			input = raw_cmd_string,
			func = func
		})
	end
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
			return self:InterpretCommand(text)
		end
	elseif string.gsub(text,"%s","") ~= "" then
		self:Log("> " .. text)
		return self:InterpretInput(text)
	end
end

function Console:InterpretInput(raw_string)
--	local s = string.match(raw_string,"[^%s]*.*")
	local s = raw_string
	local force_ordered_results = false --todo
	local result
	local func,err = loadstring(s)
	if err then 
		self:Log("Error loading chunk:")
		self:Log(err)
	elseif func then 
		if force_ordered_results then
			result = pcall(func)
		else
			result = {pcall(func)}
		end
		if result[1] == true then
			table.remove(result,1)
			logall(result)
		end
	end
	self:AddToInputLog(
		{
			raw_input = raw_string,
			input = s,
			func = func
		}
	)
	local out_s
	local color_data = {}
	if result then
		local value_sep = "\n"
		local sep_length = utf8.len(value_sep)
		local current = 1
		for result_num,v in ipairs(result) do 
			local _type = type(v)
			local _v = tostring(v)
			local color = self:GetLogColorByDataType(_type)
			local length = utf8.len(_v)
			local new_current = current + length
			color_data[result_num] = {
				start = current,
				finish = new_current,
				color = color
			}
			if out_s then 
				out_s = out_s .. value_sep .. _v
				current = new_current + sep_length
			else
				out_s = _v
				current = new_current + sep_length
			end
		end
	else
		out_s = nil
	end
--	self:AddToOutputLog(result)
	return out_s,color_data --colors here
end

function Console:GetLogColorByDataType(_type)
	local data_type_colors = self.data_type_colors
	local setting_name = _type and data_type_colors[_type]
	local color = setting_name and self.settings[setting_name] or self.settings.style_data_color_misc
	return Color(string.format("%06x",color))
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


--commands

function Console:cmd_help(params,subcmd)
	local cmd_data = subcmd and self._registered_commands[subcmd] 
	if cmd_data then 
		self:Log("/" .. tostring(subcmd))
		self:Log(cmd_data.desc)
		self:Log(cmd_data.manual)
		if cmd_data.parameters then 
			for k,v in pairs( cmd_data.parameters ) do 
				if not v.hidden then
					self:Log("-" .. k .. " " .. tostring(v.arg_desc))
					self:Log(tostring(v.short_desc))
				end
			end
		end
	else
		for cmd_name,_cmd_data in pairs(self._registered_commands) do 
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
	if name == "" then
		name = params.name
	end
	local category = params.category
	local slot = tonumber(params.slot)
	
	local function check_weapon(weapon_id,data)
		if slot then 
			if data.use_data and data.use_data.selection_index == slot then 
				--found
			else
				return false
			end
		end
		local name_id = data.name_id 
		local localized_name
		local localized_name_lower
		local weapon_id_lower = string.lower(weapon_id)
		if name_id then
			localized_name = managers.localization:text(name_id)
			localized_name_lower = string.lower(localized_name)
		end
		
		if name then
			local name_lower = string.lower(name)
			if localized_name and string.find(localized_name_lower,name_lower) then
				--pass
			elseif string.find(weapon_id_lower,name_lower) then
				--pass
			else
				--fail
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
	if name then 
		search_feedback_str = search_feedback_str .. ": [" .. tostring(name) .. "]"
	else
		search_feedback_str = search_feedback_str .. " all weapons"
	end
	if category then 
		search_feedback_str = search_feedback_str .. " with category [" .. tostring(category) .. "]"
	end
	if slot then
		search_feedback_str = search_feedback_str .. " in slot [" .. tostring(slot) .. "]"
		if slot == 1 then 
			search_feedback_str = search_feedback_str .. " (primary weapons)"
		elseif slot == 2 then
			search_feedback_str = search_feedback_str .. " (secondary weapons)"
		elseif slot == 3 then
			search_feedback_str = search_feedback_str .. " (underbarrel weapons)"
		end
	end
	search_feedback_str = search_feedback_str .. "..."
	self:Log(search_feedback_str)
	for weapon_id,data in pairs(tweak_data.weapon) do 
		if type(data) == "table" then
			if check_weapon(weapon_id,data) then
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


function Console:cmd_echo(param,s)
	s = tostring(s)
	for id,value in pairs(self._user_vars) do 
		s = string.gsub(s,"$" .. id,tostring(value))
	end
--	self:InterpretInput("return " .. tostring(s))
	self:Log(s)
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

function Console:GetUserVar(id)
	return self._user_vars[id]
--	for _,id in pairs({...}) do 
--		self:Log(self.VAR_PREFIX .. tostring(id) .. " " .. tostring(self._user_vars[id]))
--	end
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
	self:Log("Initiating a new console session.")
	self:Log("Welcome to the unofficial console!")
	self:Log("Type /help for a list of commands.")
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
	self._window_instance = ConsoleModDialog and ConsoleModDialog:new(managers.system_menu,self.dialog_data)
end

function Console:ShowConsoleWindow()
	if self._window_instance then
		managers.system_menu:_show_instance(self._window_instance,true)
	end
end

function Console:HideConsoleWindow()
	if self._window_instance then
		self._window_instance:hide()
	end
end

function Console:ToggleConsoleWindow()
	if self._window_instance then
		local state = not self._window_instance.is_active
		if state then 
			self:ShowConsoleWindow()
		else
			self:HideConsoleWindow()
		end
	end
end


--i/o
function Console:SaveInputLog() --not used
--[[
	local file = io.open(self._input_log_file_path,"w+")
	if file then
		file:write(self._input_log)
		file:close()
	end
--]]
end

function Console:LoadInputLog()
	if not self._is_reading_log then
		local file = io.open(self._input_log_file_path,"r")
		if file then
			local load_chunks_on_read = false

			local buffer_size = self._io_buffer_size
			local str = ""
			local timeout = self._operation_timeout
			local t = os.clock()
			while true do 
				local _t = os.clock()
				if _t - t > timeout then 
					self:Log(string.format("Took too long reading file %s (%is)",self._input_log_file_path,_t - t))
					break
				end
				local block = file:read(buffer_size)
				if not block then 
					break
				end
				str = str .. block
			end
			if str ~= "" then
				for i,line in ipairs(string.split(str,"\n")) do 
					local func,err
					if load_chunks_on_read then --probably not necessary since loadstring is kinda heavy
						func,err = loadstring(line)
						if err then
							--silent fail- if these are logged, the output log would probably balloon in size
							--add errors to table internally?
							func = nil
						end
					end
					self._input_log[i] = {
						input = line,
						raw_input = line,
						saved_input = nil,
						func = func
					}		
				end
			end
			file:close()
		end
	end
end

function Console:AddToInputLog(data)
	table.insert(self._input_log,#self._input_log+1,data)
	if self.settings.input_log_enabled then
		local s = data.raw_input or data.input
		if s then
			self:WriteToInputLog(string.gsub(s,"\n"," "),false)
		end
	end
end

function Console:WriteToInputLog(s,force) --append to log
	if s then
		local buffer_enabled = self.settings.log_buffer_enabled
		if not self._is_reading_log and (force or not buffer_enabled) then
			--do it write now (haha)
			local file = io.open(self._input_log_file_path,"a")
			if file then
				file:write("\n" .. s)
				file:close()
			end
		else
			--if is reading log, line is forced into the buffer anyway even if buffer is disabled,
			--effectively skipping it but still preserving the data (until the state reloads/session ends)
			
			--queue writing it to a "buffer" and flush the buffer at regular intervals
			table.insert(self._buffers.input_log,1,s)
		end
	end
end

function Console:FlushInputLogBuffer()
	if not self._is_reading_log then
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
end


function Console:SaveOutputLog() --save full log directly
	if not self._is_reading_log then
		local file = io.open(self._output_log_file_path,"w+")
		if file then
			file:write(self._output_log)
			file:close()
		end
	end
end

function Console:LoadOutputLog() --load from output
	local file = io.open(self._output_log_file_path,"r")
	self._is_reading_log = true
	if file then
		local buffer_size = self._operation_timeout
		local timeout = self._io_buffer_size
		local str = ""
		local t = os.clock()
		while true do 
			local _t = os.clock()
			if _t - t > timeout then 
				self:Log(string.format("Took too long reading file %s (%is)",self._output_log_file_path,_t - t))
				break
			end
			local block = file:read(buffer_size)
			if not block then 
				break
			end
			str = str .. block
		end
		if str ~= "" then
			self._output_log = string.split(str,"\n")
		end
		file:close()
	end
	self._is_reading_log = false
end

function Console:AddToOutputLog(s)
	table.insert(self._output_log,#self._output_log+1,s)
	if self.settings.output_log_enabled then 
		self:WriteToOutputLog(s,false)
	end
end

function Console:WriteToOutputLog(s,force)
	local buffer_enabled = self.settings.log_buffer_enabled
	if not self._is_reading_log and (force or not buffer_enabled) then
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
	if not self._is_reading_log then
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

function Console:ResetSettings(soft_reset)
	--empty settings menu instead of creating a new settings menu, since some classes may depend on that specific table reference
	
	if not soft_reset then
		--optionally can choose to preserve any vars that aren't overwritten/defined in default settings, ie. user-created vars or potential future advanced settings
		for k,v in pairs(self.settings) do 
			self.settings[k] = nil
		end
	end
	for k,v in pairs(self.default_settings) do 
		self.settings[k] = v
	end
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
--		self:Log("Font " .. font_path .. " is verified.")
	else
		--assume that if the .font is not loaded, then the .texture is not either (both are needed anyway)
--		self:Log("Font " .. font_path .. " is not created!")
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
--		self:Log("Resource ready " .. tostring(font_path))
		self._is_font_asset_load_done = true
	else
		self._is_font_asset_load_done = false
		
--		self:Log("Resource not ready " .. tostring(font_path))
--		self:Log("Starting load: " .. tostring(file_path))
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
--				self:Log("Completed manual asset loading for " .. tostring(resource_type_ids) .. " " .. tostring(resource_ids))
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
--				self:Log("Error: not done???")
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
		
	do
		local texture_ids = Idstring("texture")
		local file_name = "guis/textures/consolemod/buttons_atlas"
		local file_path = Console._mod_path .. "assets/" .. file_name
		local file_name_ids = Idstring(file_name)
		BLT.AssetManager:CreateEntry(file_name_ids,texture_ids,file_path .. ".texture")
		managers.dyn_resource:load(texture_ids,file_name_ids,DynamicResourceManager.DYN_RESOURCES_PACKAGE,function() end)
	end

	if not Console.settings.safe_mode then 
		if Console.settings.output_log_enabled then 
			Console:LoadOutputLog()
		end
		if Console.settings.input_log_enabled then 
			Console:LoadInputLog()
		end
		--[[
		if not Console._safe_mode then
			Console.orig_BLTKeybindsManager_update = BLTKeybindsManager.update
			function BLTKeybindsManager:update(...)
				if Console._window_instance and Console._window_instance.is_active then 
					return
				end
				return Console.orig_BLTKeybindsManager_update(self,...)
			end
		end
		--]]
	end
	MenuCallbackHandler.callback_dcc_console_window_focus = function(self)
		Console:ToggleConsoleWindow()
	end
	MenuCallbackHandler.callback_dcc_close = function(self) end --not used
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
			name = {
				arg_desc = "[name]",
				short_desc = "The name to search for.",
				hidden = true
			},
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
	Console:RegisterCommand("help",{
		str = nil,
		desc = "Brief list of commands.",
		manual = "/help [command name]",
		parameters = {},
		func = callback(Console,Console,"cmd_help")
	})
	--Console:RegisterCommand("weaponinfo")
	Hooks:Call("ConsoleMod_RegisterCommands",Console)
	
	
	Console:CreateConsoleWindow()

	MenuHelper:LoadFromJsonFile(Console._menu_path, Console, Console.settings)
end)

--custom menu creation
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
	"_create_commandprompt"
}
for _,name in pairs(deprecated_func_list) do 
	Console[name] = Console[name] or dummy
end