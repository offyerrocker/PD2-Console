--[[

*******************  Bug list [high priority] ******************* 
- Fix internal/external Log/logall use so that user-made Log/logall calls can safely be used on Console's own objects without causing stack overflows
	- look for another breaker solution
- [Console] memory crash when using 166k-168k output logs
- Figure out a memory-safe(r) solution to putting all history output in one continuous string in a single Text object


*******************  Bug list [low priority] ******************* 

- [ConsoleModDialog] separate callbacks in create_gui into their own functions

- [ConsoleModDialog] Dragging any clickable object results in a "drag" mousepointer even if the object is not draggable
	-solution: add per-item "drag" string mousepointer value


******************* Feature list todo: ******************* 
- var pipelining from command to command
	- eg. saving return values of list from /weaponname to $WEAPONS
- change removing redundant spaces (allow unfiltered string streams per command)
- "Debug HUD"
	- show aim-at target (tweakdata and health)
	- show xyz pos
- optional pause on open console (sp only)
	- unpause on settings toggle
- straighten out Log/Print/output call flow
	- different levels of logging
	print/log behavior option checkboxes
- mouse-selectable output text
- mouse-selectable input text
- scale scrollbar size to num of history lines

- rounded corners in ConsoleModDialog
	- center submit button and create its own subpanel
	- increase Console header size
- ConsoleModDialog scroll button click input repeat

******************* Secondary feature todo ******************* 
- shortcut function to get log/datatype color from settings
- option to disable color coded logs
- allow changing type colors through settings
- [ConsoleModDialog] mouseover tooltips for buttons after n seconds
- batch file folder system in saves
	autoexec batch-style files
- option to de-focus the console and keep it open while playing without hiding it
- "/" key shortcut to open console window
	- or other keys; allow other keys as command character
- "is holding scroll" for temporary scroll lock 
- button-specific mouseover color
- session pref with existing vars
- tab key autocomplete
- preview history in dialog ui
	show number of history steps?
- "undo" steps history
- limit number/size of input/output logs (enforced on save and load)
- history line nums + ctrl-G navigation?
- separate session "settings" from normal configuration settings?
- lookup asset loaded table so check when specific assets are loaded without having to make redundant dynresource checks


******************* Commands todo *******************

- /help - alphabetize
	-s search function
- /restart
	-silent mode parameter (no countdown)
	-also remember to code the chat countdown
- print
- echo 
	- escape aliases before applying, so that expanded aliases don't trigger additional expansions
- /alias
	- fix var_func_str
- setvar/session var business
	$ var values (overrides normal vars, not saved)
	@ temp var values (saved between sessions)

- // executes previous stored loadstring function
- /// re-evaluates and executes previous stored input

- /clear command to clear logs


- warning/text-based confirm prompt eg. when a query is expected to have lots of results

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
	Console._autoexec_menustate_path = save_path .. "autoexec_menustate.lua"
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
		"window_input_submit_color", --todo color schemes instead of individual color entries?
		"window_button_normal_color",
		"window_button_highlight_color",
		"window_frame_color",
		"window_bg_color",
		"window_caret_color",
		"window_prompt_color",
		"style_color_error",
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
		console_pause_game_on_focus = true,
		log_input_enabled = true,
		log_output_enabled = false,
		log_buffer_enabled = true,
		log_buffer_interval = 10, --seconds between flushes
		style_color_error = 0xff6262,
		style_data_color_function = 0x7fffff,
		style_data_color_string = 0x7f7f7f,
		style_data_color_number = 0xa8ff00,
		style_data_color_table = 0xffff00,
		style_data_color_boolean = 0x4c4cff,
		style_data_color_nil = 0x4c4c4c,
		style_data_color_thread = 0xffff7f,
		style_data_color_userdata = 0xff4c4c,
		style_data_color_misc = 0x888888,
		input_mousewheel_scroll_direction_reversed = false,
		input_mousewheel_scroll_speed = 1,
		console_show_nil_results = false,
		window_scrollbar_lock_enabled = true,
		window_scroll_direction_reversed = true,
		window_text_normal_color = 0xffffff,
		window_text_highlight_color = 0xffd700, --the color of the highlight box around the text
		window_text_stale_color = 0x777777, --the color of any logs pulled from history log (read from disk, ie from previous state/session)
		window_text_selected_color = 0x000000, --the color of highlighted text
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
		window_frame_color = 0x3c3c3c,
		window_frame_alpha = 1,
		window_input_submit_color = 0x7e5c35, --the color of the submit button
		window_bg_color = 0x252525, --the color of the body box bg, and the bg behind the input text box
		window_bg_alpha = 0.9,
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
		"log_input_enabled",
		"log_output_enabled",
		"log_buffer_enabled",
		"log_buffer_interval",
		"style_color_error",
		"console_pause_game_on_focus",
		"console_params_guessing_enabled",
		"input_mousewheel_scroll_direction_reversed",
		"input_mousewheel_scroll_speed",
		"console_show_nil_results",
		"window_scrollbar_lock_enabled",
		"window_scroll_direction_reversed",
		"window_text_normal_color",
		"window_text_highlight_color",
		"window_text_selected_color",
		"window_text_stale_color",
		"window_button_normal_color",
		"window_button_highlight_color",
		"window_frame_color",
		"window_frame_alpha",
		"window_input_submit_color",
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
	
	Console._aliases = {
	--[[ ex.
		test = {
			value = 12345
		},
		time = {
			get_value = function()
				return os.date("%X")
			end
		},
		nothing = {
			--nothing!
		}
		FOO = { --all instances of $FOO are replaced with the value: 12345
			value = 12345
		},
		CURRENT_TIME = { --since the get_value function is provided, the value parameter is ignored, and all instances of $CURRENT_TIME are replaced with the return value of get_value()
			value = 45678,
			get_value = function()
				return os.date("%X")
			end
		},
		MoCkInG_CaSe_vAR = {
			value = "meeee"
		}
		
		
	--]]
	}
	Console._operation_timeout = 5
	Console._io_buffer_size = 2^13
	Console._buffers = {
		input_log = {},
		output_log = {}
	}
	Console.PREFIXES = {
		COMMAND = "/",
		ALIAS = "$"
	}
	Console._is_reading_log = false
	--placeholder values for things that will be loaded later
	Console._restart_timer = false --used for /restart [timer] command: tracks next _restart_timer value to output (every second)
	Console._restart_timer_t = false  --used for /restart [timer] command: tracks time left til 0 (restart)
	Console._colorpicker = nil
	Console._is_font_asset_load_done = nil --if font is loaded
	Console._is_texture_asset_load_done = nil
end

do --load ini parser
	local f,e = blt.vm.loadfile(Console._mod_path .. "utils/LIP.lua")
	local lip
	if e then 
		log("[CONSOLE] ERROR: Failed loading LIP module. Try re-installing BeardLib if this error persists.")
	elseif f then 
		lip = f()
	end
	if lip then 
		Console._lip = lip
	end
end

do --hooks and command registration
	Hooks:Register("ConsoleMod_RegisterCommands")
	Hooks:Register("ConsoleMod_AutoExec")
	
	Hooks:Add("ConsoleMod_RegisterCommands","consolemod_load_base_commands",function(console)
		console:RegisterCommand("restart",{
			str = nil,
			desc = "Reloads the Lua state. Restart the heist day if in a heist, or reload the menu if at the main menu.",
			manual = "/restart [String cancel]",
			arg_desc = "(Boolean) Any truthy value as the first argument will cancel any ongoing restart timer.",
			name = {
				arg_desc = "[timer]",
				short_desc = "(Int) Optional. The number of seconds to delay restarting by. If in-game, will display a timer in chat similar to the one available in the base game. If not supplied, restarts instantly."
			},
			name = {
				arg_desc = "[noclose]",
				short_desc = "(Boolean) Optional. Any truthy value will prevent the Console window from closing automatically if a restart is performed immediately.\nThis is because the Console window is a dialog, and any open dialog will delay a restart for as long as the dialog is open."
			},
			func = callback(console,console,"cmd_restart")
		})
		console:RegisterCommand("partname",{
			str = nil,
			desc = "Search for a part by localized name/description, internal name/description, internal id, or blackmarket id.",
			manual = "Usage: /partname [search key]\n\nParameters:\n-type [attachment type]\n-weapon [weapon id]",
			arg_desc = "(String) The name of the weapon attachment to search for. Single-term, case insensitive, spaces okay.",
			parameters = {
				type = {
					arg_desc = "[attachment type]",
					short_desc = "(String) The attachment type to filter for, eg. silencer, barrel, stock, etc. Must be exact type match."
				},
				weapon = {
					arg_desc = "[weapon]",
					short_desc = "(String) The weapon id to filter for, eg. m134, flamethrower, saw, m1911, or new_m4. If supplied, partname will only display attachments that can be applied to this weapon. Must be exact weapon_id match."
				}
			},
			func = callback(console,console,"cmd_partname")
		})
		console:RegisterCommand("weaponname",{
			str = nil,
			desc = "Search for a weapon by localized name/description, internal name/description, internal id, or blackmarket id.",
			manual = "Usage: /weaponname [search key]",
			arg_desc = "(String) The name of the weapon to search for. Single-term, case insensitive, spaces okay.",
			parameters = {
				name = {
					arg_desc = "[name]",
					short_desc = "(String) The name to of the weapon search for. Single-term, case insensitive, spaces okay.",
					hidden = true
				},
				category = {
					arg_desc = "[category]",
					short_desc = "(String) The weapon category to filter for, eg. shotgun, smg, lmg, etc. Must be exact category match."
				},
				slot = {
					arg_desc = "[slot]",
					short_desc = "(Integer) The weapon slot number to filter for, eg. 1, 2, etc. Must be exact slot match."
				}
			},
			func = callback(console,console,"cmd_weaponname")
		})
		console:RegisterCommand("help",{
			str = nil,
			desc = "Brief list of commands.",
			manual = "/help [command name]",
			arg_desc = "(String) The name of the command to search for. Single-term, case insensitive, no spaces.",
			parameters = {},
			func = callback(console,console,"cmd_help")
		})
		console:RegisterCommand("echo",{
			str = nil,
			desc = "Prints a string and/or aliases back to the console.",
			manual = "/echo [string]",
			arg_desc = "(String) The text to print.",
			parameters = {},
			func = callback(console,console,"cmd_echo")
		})
		console:RegisterCommand("alias",{
			str = nil,
			desc = "Assigns a temporary variable with a name and value of your choice. This variable can be accessed with $VARNAME, and is effectively a string substitution/shortcut tool usable in console commands.",
			manual = "/alias [var name] [var value] [Optional var function]",
			arg_desc = "(String) The text to print.",
			parameters = {
				loadstring = {
					arg_desc = "",
					short_desc = "If supplied, attempts to process the function or var through loadstring, instead of only saving the string value. Required if you are supplying a function."
				}
			},
			func = callback(console,console,"cmd_alias")
		})
	end)

	Hooks:Add("ConsoleMod_AutoExec","consolemod_autoexec_listener",function(console,state)
		console:AutoExec(state)
	end)
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

function Console.string_replace(str,start,finish,new)
	local str_len = string.len(str)
	local a,b
	
	if start > 1 then 
		a = string.sub(str,1,start - 1)
	else
		a = ""
	end
	
	if finish < str_len then 
		b = string.sub(str,finish + 1)
	else
		b = ""
	end
	return a .. new .. b
end

function Console.file_exists(path)
	if SystemFS then
		return SystemFS:exists(path)
	else
		return file.FileExists(path)
	end
end

--loggers
Console.blt_log = Console.blt_log or _G.log
function Console:Log(info,params)
	local _info = tostring(info)
	if self._window_instance then 
		params = params or {}
		if params.skip_window_instance then
			--don't feed back to ConsoleModDialog instance
		elseif params.color_ranges and type(params.color_ranges) == "table" then
			self._window_instance:add_to_history(_info,params.color_ranges)
		else
			local color
			if params.color then 
				color = params.color
			else
				local _type = type(info)
				local setting_name = self.data_type_colors[_type]
				if setting_name then 
					color = self.hex_number_to_color(self.settings[setting_name])
				end
			end
			if color then
				local length = utf8.len(_info)
				self._window_instance:add_to_history(_info,{
					{
						start = 0,
						finish = 1 + length,
						color = color
					}
				})
			else
				self._window_instance:add_to_history(_info)
			end
		end
	end
	self:AddToOutputLog(_info)
	
	local should_blt_log = true
	if should_blt_log then 
		Console.blt_log(string.format(managers.localization:text("menu_consolemod_window_log_prefix_str"),_info))
	end
	
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
		if os.clock() > t + timeout then
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
			local color_setting_name = data_type and self.data_type_colors[data_type]
			local color = color_setting_name and self.hex_number_to_color(self.settings[color_setting_name] or self.settings.style_data_color_misc)
			self:Log("[" .. tostring(k) .. "] : [" .. tostring(v) .. "]",{color = color})
--			Console:Log("[" .. tostring(k) .. "] : [" .. tostring(v) .. "]")
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
	
	if self._restart_timer_t then --time at which heist will restart
		local time_left = math.ceil(self._restart_timer_t - t) --seconds left to restart
		if (not self._restart_timer) or (self._restart_timer - time_left) >= 1 then --output only once, not every update
			self._restart_timer = self._restart_timer or time_left 
			self._restart_timer = time_left
			
			self:Log(string.format(managers.localization:text("menu_consolemod_restart_dialog_countdown"),time_left),{color = Color.yellow})
		end
		if time_left <= 0 then 
			managers.game_play_central:restart_the_game()
			self._restart_timer_t = nil
		end
	end
	
end

function Console:InterpretCommand(raw_cmd_string)
	--command string must start with "/"
	
	self.blt_log(self.settings.window_prompt_string .. raw_cmd_string)

	--separate cmd_name (cmd_name aliasing is addressed earlier)
	--check for substitutions
	--separate positional parameters (aka "arguments"; everything between cmd_name and normal parameters)
	--separate normal parameters (aka "parameters"; key-value pairs whose keys are denoted by a hyphen character "-" immediately preceding the key token)
	--restore non-alias substitutions
	
	local cmd_string = string.sub(raw_cmd_string,2) --remove forwardslash
	local cmd_name = string.match(cmd_string,"[^%s]*")--[%a%s]+")
	
	if not cmd_name or cmd_name == "" then
		return
	end

	local command_data = self._registered_commands[cmd_name]
	if not command_data then 
		self:Log(string.format(managers.localization:text("menu_consolemode_error_command_missing"),cmd_name),{color=self.hex_number_to_color(self.settings.style_color_error)})
		return
	end
	
	local name_len = string.len(cmd_name)
	cmd_string = string.sub(cmd_string,name_len + 2) --remove cmd name from the string; extra index for end of string and space 
	
	local function esc(s)
		--escape any characters that need escaping (ironically this step only needs to be performed on the substitutes)
		local escape_magic_chars = {
			'(',
			')',
			'.',
			'+',
			'-',
			'*',
			'?',
			'^',
			'$'
		}
		for _,character in pairs(escape_magic_chars) do 
			local _s = s
			s = string.gsub(s,"%" .. character,"%%" .. character)
		end
		return s
	end
	
	
	local cmd_string_subbed = cmd_string
	
	local sub_patterns = {
--		'"[^%"]*"',
--		"'[^%']*'",
		"%([%w]*%)",
		"%$[%w_]+"
	}
	local sub_index = 1
	local sub_id = 1

	local substitutions = {}
	for i,pattern in ipairs(sub_patterns) do 
		local length = utf8.len(cmd_string_subbed)
		local do_exit = false
		
		--find substitution
		repeat
			local a,b = string.find(cmd_string_subbed,pattern,sub_index)
			if not (a and b) or (sub_index >= length) or (a == b) then 
				do_exit = true
			else
				local token = string.sub(cmd_string_subbed,a,b)
				local new_sub
				if i == 3 then
					local var = self:GetAlias(token)
					if var ~= nil then 
						new_sub = var
					end
				else
					new_sub = string.format("##consolemod_sub%i##",sub_id) --idstring is just used as a replacement 
					sub_id = sub_id + 1
				end	
				if new_sub then
					table.insert(substitutions,#substitutions+1,{
						a = a,
						b = b,
						s1 = token,
						s2 = new_sub,
						is_alias = i == 3
					})
				end
				sub_index = b + 1
			end
		until do_exit
	end
	
	--perform substitution 
	for j=#substitutions,1,-1 do 
		local sub_data = substitutions[j]
		cmd_string_subbed = self.string_replace(cmd_string_subbed,sub_data.a,sub_data.b,sub_data.s2)
		if sub_data.is_alias then 
			--remove the substitution data after execution so that it's not reverted afterward
			table.remove(substitutions,j)
		end
	end
	
	--if guessing is enabled, collect the possible parameters for this command for later
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
	
	--now that quotations and aliases are out of the way, remove extra spaces
	cmd_string_subbed = string.gsub(cmd_string_subbed,"%s+"," ")
	
	local parameters_pattern = "[%-][%a%p]+[^%-]*"
	local params_start,params_finish = string.find(cmd_string_subbed,parameters_pattern)
	
	--get positional arguments
	local args_string
	if params_start then
		args_string = string.sub(cmd_string_subbed,1,params_start - 1) --extra index for the space
	else
		args_string = cmd_string_subbed
	end
	
	
	
	--find normal parameters
	local params = {} --holds params that are being matched to existing params if param guessing is enabled
	for parameter_string in string.gmatch(cmd_string_subbed,"%-[%a%p]+[^%-]*") do 
--		local _token = string.sub(token,params_start+1)
		local param_name,param_value
		for token in string.gmatch(parameter_string,"[%w%p][^%s]*") do 
			if param_value and param_value ~= "" then 
				param_value = param_value .. " " .. token
				--3. which are each separated by a single space character " " (but no trailing space)
			else
				if not param_name then
					param_name = string.sub(token,2) --remove hyphen
					param_value = ""
					--1. parameter name will be the first word in this string
				else
					param_value = token
					--2. all subsequent words will be parts of the concatenated parameter value string 
				end
			end
		end
		
		if possible_params then
			local confirmed_parameter
			local i_p = table.index_of(possible_params,param_name)
			if i_p then 
				table.remove(possible_params,i_p)
				confirmed_parameter = true
			end
		end
		table.insert(params,#params+1,{name = param_name,value = param_value,confirmed = confirmed_parameter})
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
	
	local cmd_params = {} --holds final params
	
	--restore substitutions
	if #substitutions > 0 then 
	
		for i=#substitutions,1,-1 do 
			local sub_data = table.remove(substitutions,i)
			local orig = sub_data.s1
			local new = esc(sub_data.s2)

			--restore substitutions to positional parameters
			args_string = string.gsub(args_string,new,orig)
			
			--restore substitutions to normal parameters (and their parameter names)
			for _,param_data in ipairs(params) do 
				local d = string.gsub(param_data.name,new,orig)
				local e = string.gsub(param_data.value,new,orig)
				cmd_params[d] = e
			end
		end
	else
		for _,param_data in ipairs(params) do 
			cmd_params[param_data.name] = param_data.value
		end
	end
	
	if command_data.func then 
		command_data.func(cmd_params,args_string)
		self:AddToInputLog({
			raw_input = raw_cmd_string,
			input = raw_cmd_string,
			func = nil --command_data.func
		})
	elseif command_data.str then 
		local func,err = loadstring(command_data.str)
		if func then
			command_data.func = func
			return pcall(func,cmd_params,args_string)
		elseif err then
			self:Log(err)
		end
		self:AddToInputLog({
			raw_input = raw_cmd_string,
			input = raw_cmd_string,
			func = func
		})
	end
end


function Console:callback_confirm_text(dialog_instance,text)
	local first_char = string.sub(text,1,1)
	if first_char == self.PREFIXES.ALIAS then
		local _text = string.sub(text,2) --remove alias signifier
		local a,b = string.find(_text,"[^%s]*")
		if a then
			local alias_token = string.sub(_text,a,b)
			local alias = self:GetAlias(alias_token)
			if alias then
				text = self.string_replace(_text,a,b,alias)
				first_char = string.sub(text,1,1)
			end
		else
			--only command name (no params)
			local alias = self:GetAlias(_text)
			if alias then 
				text = alias
			end
		end
	end	
	if first_char == self.PREFIXES.COMMAND then 
		local input_log = self._input_log
		if text == string.rep(self.PREFIXES.COMMAND,2) then 
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
		return self:InterpretInput(text)
	end
end

function Console:InterpretInput(raw_string)
	self.blt_log(self.settings.window_prompt_string .. raw_string)
--	local s = string.match(raw_string,"[^%s]*.*")
	local s = raw_string
	local force_ordered_results = false --todo
	local result
	local func,err = loadstring(s)
	if err then 
		local err_color = self.hex_number_to_color(self.settings.style_color_error)
		self:Log("Error loading chunk:",{color=err_color})
		self:Log(err,{color=err_color})
	elseif func then 
		if force_ordered_results then
			result = pcall(func)
		else
			result = {pcall(func)}
		end
		if result[1] == true then
			table.remove(result,1)
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
			self.blt_log(string.format(managers.localization:text("menu_consolemod_window_log_prefix_str"),_v))
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

function Console:AutoExec(c) --executes the contents of a lua file
	if c == "menu_state" then
		if self.file_exists(self._autoexec_menustate_path) then 
			self:Log(dofile(self._autoexec_menustate_path))
		end
	end
end

--commands

function Console:cmd_help(params,subcmd)
	local cmd_data = subcmd and self._registered_commands[subcmd] 
	if cmd_data then 
		self:Log("/" .. tostring(subcmd))
		self:Log(cmd_data.arg_desc)
		self:Log(cmd_data.desc)
		self:Log(cmd_data.manual)
		if cmd_data.parameters then 
			for param_name,param_data in pairs( cmd_data.parameters ) do 
				if not param_data.hidden then
					self:Log("-" .. param_name .. " " .. tostring(param_data.arg_desc))
					self:Log(tostring(param_data.short_desc))
				end
			end
		end
	else
		for cmd_name,_cmd_data in pairs(self._registered_commands) do 
			if not _cmd_data.hidden then
				self:Log("/" .. tostring(cmd_name))
				self:Log(_cmd_data.desc)
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

function Console:cmd_restart(params,timer)
	timer = timer == "" and params.timer or timer
	if timer == "cancel" then
		self._restart_timer_t = nil
		self._restart_timer = nil
	else
		timer = timer and tonumber(timer)
		if self._restart_timer_t and timer then 
			--timer has already started
			self._restart_timer_t = Application:time() + timer
		elseif not timer or timer <= 0 then
			if managers.game_play_central then
				if Global.game_settings.single_player then 
				elseif managers.network and managers.network:session():is_host() then
					if params.vote then 
						--[[
						local votemanager = managers.vote
						if not votemanager._stopped then
							votemanager._callback_type = "restart"
							votemanager._callback_counter = TimerManager:wall():time() + tonumber(timer)		
						end
						--]]
						return
					end
				else
					self:Log("You cannot restart the game in which you are not the host!",{color = Color.red})
					return
				end
				if not params.noclose then 
					self:HideConsoleWindow()
				end
				managers.game_play_central:restart_the_game()
			else
				if setup and setup.load_start_menu then
					if not params.noclose then
						self:HideConsoleWindow()
					end
					setup:load_start_menu()
				end
			end
		end
	end
	
end

function Console:cmd_alias(params,args)
	local _args = string.split(args," ")
	local do_loadstring = params.loadstring --if true, attempts to read the provided func or value as a chunk, instead of just storing the string value
	local var_name_str = _args[1]
	local var_value_str = _args[2]
	local var_func_str -- = _args[3]
	
	local var_value,var_func,err,feedback_str,feedback_type
	
	if var_name_str and var_name_str ~= "" then
		if var_func_str and do_loadstring then 
			var_func,err = loadstring(var_func_str)
			if var_func then
				feedback_str = var_func_str
				feedback_type = type(var_func)
				--success
			else
				local err_col = self.hex_number_to_color(self.settings.style_color_error)
				self:Log("Error loading func chunk:",{color=err_col})
				self:Log(var_func_str,{color=err_col})
				self:Log(err,{color=err_col})
				return
			end
		elseif var_value_str then
			if do_loadstring then
				var_func,err = loadstring("return " .. var_value_str)
				if var_func then 
					feedback_str = var_value_str
					feedback_type = type(var_func)
					--success
				else
					local err_col = self.hex_number_to_color(self.settings.style_color_error)
					self:Log("Error loading string chunk:",{color=err_col})
					self:Log(var_value_str,{color=err_col})
					self:Log(err,{color=err_col})
					return
				end
			else
				var_value = var_value_str
				feedback_str = var_value
				feedback_type = type(var_value)
			end
		end
	
		if var_value or var_func then
			self:SetAlias(var_name_str,var_value,var_func)
		end
		
		if feedback_str then 
			local var_len = string.len(feedback_str)
			local type_color_name = self.data_type_colors[feedback_type]
			local feedback_col = self.hex_number_to_color(self.settings[type_color_name or "style_data_color_misc"])
			
			self:Log(string.format(managers.localization:text("menu_consolemod_cmd_alias_assigned"),feedback_str,self.PREFIXES.ALIAS .. var_name_str),{color_ranges = {{start = 1,finish = var_len + 1,color=feedback_col}}})
		end
		
	end
end


function Console:cmd_echo(param,s)
	s = tostring(s)
	local ALIAS_PREFIX = self.PREFIXES.ALIAS
	local prefix_search = "%" .. ALIAS_PREFIX
	if string.find(s,prefix_search) then
		for id,data in pairs(self._aliases) do 
			local cached_value = nil
			local alias = prefix_search .. id
			if string.find(s,alias) then 
				local value
				if type(data.get_value) == "function" then 
					local success = pcall(function()
						value = data.get_value()
					end)
				else
					value = data.value
				end
				s = string.gsub(s,alias,tostring(value))
			end
		end
	end
	self:Log(s)
end

function Console:SetAlias(id,val,func)
	if string.sub(tostring(val),1,1) == self.PREFIXES.ALIAS then 
		val = self:GetUserVar(val)
	end
	local data = {
		value = val,
		get_value = func
	}
	self:_SetAlias(id,data)
end

function Console:_SetAlias(id,data)
	self._aliases[id] = data
end

function Console:RemoveAlias(id)
	if id ~= nil then
		self._aliases[tostring(id)] = nil
	end
end

function Console:GetAlias(id)
	local data = id and self._aliases[id]
	if data then
		if data.get_value then 
			return data.get_value()
		else
			return data.value
		end
	end
--	for _,id in pairs({...}) do 
--		self:Log(self.PREFIXES.ALIAS .. tostring(id) .. " " .. tostring(self._user_vars[id]))
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
	self:Log(managers.localization:text("dcc_window_startup_message_1"))
	self:Log(managers.localization:text("dcc_window_startup_message_2"))
	self:Log(managers.localization:text("dcc_window_startup_message_3"))
	self.dialog_data = {
		id = "ConsoleWindow",
		title = managers.localization:text("menu_consolemod_window_title"),
		text = "placeholder text",
		history_log = self._history_log,
		console_settings = self.settings,
		input_log = self._input_log,
		output_log = self._output_log,
		confirm_text_callback = callback(self,self,"callback_confirm_text"),
		save_settings_callback = callback(self,self,"SaveSettings"),
		font_asset_load_done = self._is_font_asset_load_done,
		button_list = {} --not used
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
	if self.settings.log_input_enabled then
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
	if self.settings.log_output_enabled then 
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

function Console:AddTextures()
	local texture_ids = Idstring("texture")
	local file_name = "guis/textures/consolemod/buttons_atlas"
	local file_path = Console._mod_path .. "assets/" .. file_name
	local file_name_ids = Idstring(file_name)
	BLT.AssetManager:CreateEntry(file_name_ids,texture_ids,file_path .. ".texture")
end

function Console:LoadTextures()
	local texture_ids = Idstring("texture")
	local file_name = "guis/textures/consolemod/buttons_atlas"
	local file_name_ids = Idstring(file_name)
	managers.dyn_resource:load(texture_ids,file_name_ids,DynamicResourceManager.DYN_RESOURCES_PACKAGE,
		function(done,resource_type_ids,resource_ids)
			self._is_texture_asset_load_done = done
		end
	)
end

function Console:LoadAllAssets()
	self:AddTextures()
	self:LoadTextures()
	self:AddFonts()
	self:LoadFonts()
end

--menu hooks

Hooks:Add("MenuManagerInitialize", "dcc_menumanager_init", function(menu_manager)
--	Console:LoadSettings() --temp disabled; work from default settings for now

	

	if not Console.settings.safe_mode then 
		if not Console.file_exists(Console._autoexec_menustate_path) then 
			local file = io.open(Console._autoexec_menustate_path,"w+")
			if file then
				file:write(managers.localization:text("menu_consolemod_firstboot_autoexec_comment"))
				file:close()
			end
		end
		
		Console:LoadAllAssets()
		
		if Console.settings.log_output_enabled then 
			Console:LoadOutputLog()
		end
		if Console.settings.log_input_enabled then 
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
	
	Hooks:Call("ConsoleMod_RegisterCommands",Console)
	
	Console:CreateConsoleWindow()
	
	Hooks:Call("ConsoleMod_AutoExec",Console,"menu_state")
	
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