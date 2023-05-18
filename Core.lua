--[[
===== Overview ======
- Complete 1.0 parity list
- Make a pass for localization strings
- Complete menus (and re-enable settings loading)
- Fix high-priority bugs
- Develop plan for sustainable module packages

- split Core megaclass into organized files
	- the delineations are basically already there; just separate along the seams and dofile them all on core load


*******************  Bug list [high priority] ******************* 
- Fix internal/external Log/logall use so that user-made Log/logall calls can safely be used on Console's own objects without causing stack overflows
- [Console] memory crash when using 166k-168k output logs
- [Console] Figure out a memory-safe(r) solution to putting all history output in one continuous string in a single Text object
- [ConsoleModDialog] Prevent "mouse hold" vars from sticking around after the console window is closed, if holding down a key or button when hiding console window

*******************  Bug list [low priority] ******************* 

- [ConsoleModDialog] clean up mouse drag code (save current mouse drag/hold id)

******************* Feature list todo: ******************* 
- Spacing format function, as prototyped in /thread
- save last result to an alias/var
- use coroutines for at-risk loops (ongoing)
- "Debug HUD"
	- show aim-at target (tweakdata and health)
	- show xyz pos
- straighten out Log/Print/output call flow
	- different levels of logging
	print/log behavior option checkboxes
- scale scrollbar size to num of history lines

- submit button
	- recolor text on mouseover
	- center submit button and create its own subpanel
- ConsoleModDialog scroll button click input repeat


Parity with 1.0:
	-unit tagging
	-hitbox display
	-popups (trackers but worldspace)
	-search_class()
	-commands
		-skillname/skillinfo
			- organize output strings
		-whisper
		-rot
		-tp
		-state
		-quit
		-bltmods
		-gotonav/editnav
		-forcestart
		-say
		-fwd ray
			-aim-at unit save to predefined alias/register
		


******************* Secondary feature todo ******************* 
- var pipelining from command to command
	- eg. saving return values of list from /weaponname to $WEAPONS
- optional pause on open console (sp only)
	- unpause on settings toggle
- option to disable color coded logs
- allow changing type colors through settings
- [ConsoleModDialog] mouseover tooltips for buttons after n seconds
- [ConsoleModDialog] option to de-focus the console and keep it open while playing without hiding it
- "is holding scroll" for temporary scroll lock 
- button-specific mouseover color/texture
- session pref with existing vars
- tab key autocomplete
- preview history in dialog ui
	show number of history steps?
- "undo" steps history
-highlight text color for main history panel
- limit number/size of input/output logs (enforced on save and load)
- history line nums + ctrl-G navigation?
- separate session "settings" from normal configuration settings?
- lookup asset loaded table so check when specific assets are loaded without having to make redundant dynresource checks
- "/" key shortcut to open console window
	- or other keys; allow other keys as command character
- batch file folder system in saves
	autoexec batch-style files
- [ConsoleModDialog] Rewrite to allow multiple window management?

******************* Commands todo *******************
- /bind key collision warning
- /weaponname
	-parameters to limit searches for weapon id, bm id, or name
	-parameter to search by dlc id
- /dlcname
	-search for a dlc name
- /texture
	-create console mini-window showing texture
- /help - alphabetize
	-s search function
	-/commands alias
- print
- echo 
	- preserve type data while replacing aliases to apply type colorcoding
	- escape aliases before applying, so that expanded aliases don't trigger additional expansions
- /alias
	- alias reference copying (copy func between aliases)
	- alias syntax for functions
- /cvar change advanced client/console vars or behaviors

rework all help/manual/commands text
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
	Console._keybinds_path = save_path .. "console_keybinds.ini"
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
		"style_color_system",
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
		log_blt_enabled = false,
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
		style_color_system = 0xffd700,
		input_mousewheel_scroll_direction_reversed = false,
		input_mousewheel_scroll_speed = 1,
		console_params_guessing_enabled = true,
		console_pause_game_on_focus = true,
		console_show_nil_results = false,
		console_autocull_dead_threads = true,
		window_scrollbar_lock_enabled = false,
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
		"console_pause_game_on_focus",
		"console_autocull_dead_threads",
		"console_params_guessing_enabled",
		"console_show_nil_results",
		"input_mousewheel_scroll_direction_reversed",
		"input_mousewheel_scroll_speed",
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
		"style_color_error",
		"style_color_system",
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
	
	Console.color_data = {
		["error"] = "style_color_error",
		["system"] = "style_color_system",
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
			func = function 0xd3adb33f --from loadstring
		},
		[2] = {
			input = "/echo hello -p",
			func = function 0xd3adb33f --same direct reference to previous function
		},
		[3] = {
			input = "/print $hello",
			func = function 0x1234567 --different direct referencce
		},
		[4] = {
			input = "/print $hello",
			reevaluate = true, --cue loadstring of input
			func = new function --result of loadstring
		},
		[5] = {
			input = "/set $hello 69", --set var $hello to 69
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
	Console._coroutine_counter = 0
	Console._io_buffer_size = 2^13
	Console._buffers = {
		input_log = {},
		output_log = {}
	}
	Console.PREFIXES = {
		COMMAND = "/",
		ALIAS = "$"
	}
	Console.INPUT_DEVICES = {
		MOUSE = 1,
		KEYBOARD = 2,
		CONTROLLER = 3
	}
	Console._custom_keybinds = {
		--[[ ex.
		g = {
			key_name = "g",
			key_raw = "g",
			device = 2,
			type = "command",
			action = "/echo Hello",
--			hold = 0.5,
			repeat_delay = 0,
			func = function: 0xd3adb33f (compiled from InterpretCommand("/echo Hello") )
		}
		--]]
	}
	Console._input_cache = {}
	Console._threads = {}
	Console._trackers = {}
	Console._is_reading_log = false
	--placeholder values for things that will be loaded later
	
	Console._restart_data = nil 
	--[[ ex.
		{
			restart_t = 71.58935692, -- the time at which the heist will reload (or at which the game state will reload, if in a menu)
			duration = 10, --if present and restart_t is not, starts the countdown (sets restart_t to current time + duration)
			message_t = 0, --the next time at which a chat message or Console log will be printed, giving the current countdown timer
			is_silent = false --if true, outputs the countdown to the chat/console window
		}
	--]]
	
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
			parameters = {
				timer = {
					arg_desc = "[timer]",
					short_desc = "(Int) Optional. The number of seconds to delay restarting by. If in-game, will display a timer in chat similar to the one available in the base game. If not supplied, restarts instantly."
				},
				noclose = {
					arg_desc = "[noclose]",
					short_desc = "(Boolean) Optional. Any truthy value will prevent the Console window from closing automatically if a restart is performed immediately.\nThis is because the Console window is a dialog, and any open dialog will delay a restart for as long as the dialog is open."
				},
				silent = {
					arg_desc = "[silent]",
					short_desc = "Optional. If supplied, does not send a countdown message in the chat. (Countdown messages will still be displayed in the Console.)"
				},
				vote = {
					arg_desc = "[vote]",
					short_desc = "Optional. If supplied, ignores any currennt or supplied timer and triggers a vote-restart instead."
				}
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
				},
				perks = {
					arg_desc = "[perk name, ...]",
					short_desc = "If supplied, lists all of the attachments that contain all of the supplied perks. Multiple perks can be supplied using space separators."
				},
				blueprint = {
					arg_desc = "[]",
					short_desc = "If supplied, lists the ids of all the weapons that use a given part."
				},
				npcs = {
					arg_desc = "[]",
					short_desc = "If supplied, allows NPC weapons (NPC-only weapon variants, typically with a _crew or _npc suffix) to be listed."
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
				},
				noalias = {
					arg_desc = "",
					short_desc = "If supplied, prevents interpreting aliases in the supplied value, eg. \"/alias a $b\" will interpret the new alias value $a as the literal string \"$b\"."
				}
			},
			func = callback(console,console,"cmd_alias")
		})
		console:RegisterCommand("unalias",{
			str = nil,
			desc = "Clears an alias from memory.",
			manual = "/unalias [var name]",
			arg_desc = "(String) The name of the alias.",
			parameters = {
				name = {
					arg_desc = "[name]",
					short_desc = "(String) The name of the alias to remove."
				}
			},
			func = callback(console,console,"cmd_unalias")
		})
		console:RegisterCommand("clear",{
			str = nil,
			desc = "Clears the Console window. Can be configured to clear the input/output log data on the hard disk as well.",
			manual = "",
			parameters = {
				input_clear = {
					arg_desc = "",
					short_desc = "Clears the input log and file."
				},
				output_clear = {
					arg_desc = "",
					short_desc = "Clears the output log and file."
				}
			},
			func = callback(console,console,"cmd_clear")
		})
		console:RegisterCommand("thread",{
			str = nil,
			desc = "Manage, kill, or create Console operation threads.",
			manual = "The id of a coroutine should be a number, or \"all\" to apply to all threads, or \"last\" to apply to the most recently made thread.\nAcceptable formats:\n    /thread [subcmd] [id]\n    /thread [subcmd] -n [id] \n    /thread [id]",
			parameters = {
				--[[
				new = {
					arg_desc = "[new]",
					short_desc = "Create a new coroutine with the supplied loadstring"
				},
				--]]
				kill = {
					arg_desc = "[kill]",
					short_desc = "Stops the coroutine with the given id."
				},
				list = {
					arg_desc = "[list]",
					short_desc = "If supplied with a specific id, lists all the information about that coroutine. Else, lists all coroutines."
				},
				pause = {
					arg_desc = "[pause]",
					short_desc = "If supplied, pauses a running coroutine so that it is not automatically executed on each frame."
				},
				resume = {
					arg_desc = "[resume]",
					short_desc = "If supplied, resumes a paused coroutine so that it continues to automatically execute on each frame."
				},
				priority = {
					arg_desc = "[priority]",
					short_desc = "When creating a coroutine, you can choose to specify a priority number [0-inf] which determines when your coroutine is run relative to others. Coroutines with larger priority numbers are run earlier."
				},
				number = {
					arg_desc = "[number]",
					short_desc = "Specify the id of the thread you want to manage."
				}
			},
			func = callback(console,console,"cmd_thread")
		})
		console:RegisterCommand("bind",{
			str = nil,
			desc = "Bind a key to execute a payload (a code chunk, a console command, or an in-game action).",
			manual = "",
			parameters = {
				key = {
					arg_desc = "[key]",
					short_desc = "The name of the key to bind."
				},
				type = {
					arg_desc = "[type]",
					short_desc = "(String) The type of payload for this keybind. Possible types are \"chunk\" (Lua code chunk) \"command\" (console command), or nil.\nIt is strongly recommended to specify the type, as this is much better for performance."
				},
				list = {
					arg_desc = "[list]",
					short_desc = "If supplied: lists all keybinds, their types, and their associated payloads."
				},
				--[[
				chunk = {
					arg_desc = "[chunk]",
					short_desc = ""
				},
				command = {
					arg_desc = "[command]",
					short_desc = "This 
				},
				--]]
				action = {
					arg_desc = "[action]",
					short_desc = "A string containing the command or code chunk to execute when the key is pressed."
				},
				repeat_delay = {
					arg_desc = "[repeat_delay]",
					short_desc = "(Boolean) If supplied, the keybind will continuously execute its payload while its key is held."
				},
				hold = {
					arg_desc = "[hold]",
					short_desc = "(Float) If supplied, the key must be held for this many seconds in order to execute its payload."
				},
				consoleenabled = {
					arg_desc = "",
					short_desc = "If supplied, the keybind can be executed while the Console window is open."
				},
				chatenabled = {
					arg_desc = "",
					short_desc = "If supplied, the keybind can be executed while typing in the in-game chat."
				}
			},
			func = callback(console,console,"cmd_bind")
		})
		console:RegisterCommand("unbind",{
			str = nil,
			desc = "Remove a keybind. Only applies to keybinds bound with /bind; does not apply to base-game keybinds or BLT keybinds.",
			manual = "/unbind [keyname]",
			parameters = {
				key = {
					arg_desc = "[key]",
					short_desc = "You can also use \"all\" for the key name to unbind all keybinds."
				}
			},
			func = callback(console,console,"cmd_unbind")
		})
		console:RegisterCommand("unbindall",{
			str = nil,
			desc = "Remove all keybinds. Only applies to keybinds bound with /bind; does not apply to base-game keybinds or BLT keybinds.",
			manual = "/unbindall",
			parameters = {},
			func = function() return console:cmd_unbind({key = "all"},"",{raw_input = "/unbind -key all",cmd_string = "-key all"}) end
		})
		console:RegisterCommand("skillname",{
			str = nil,
			desc = "Search for a skill by name or description.",
			manual = "/skillname",
			parameters = {},
			func = callback(console,console,"cmd_skillname")
		})
		console:RegisterCommand("info",{
			str = nil,
			desc = "Prints basic information about the application and Console mod.",
			manual = "/info",
			parameters = {},
			func = callback(console,console,"cmd_info")
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

function Console.format_time(t,params)
	local floor = math.floor
	
	local space_char
	if params.divider then 
		space_char = type(params.divider) == "string" and params.divider or " "
	else
		space_char = ""
	end
	local style = params.style
	
	local seconds = t % 60
	local _minutes = floor(t / 60)
	local minutes = _minutes % 60
	local _hours = floor(_minutes / 60)
	local hours = _hours % 24
	local days = floor(_hours / 24)
	local a = {
		seconds,
		minutes,
		hours,
		days
	}
	local b = {
		"s",
		"m",
		"h",
		"d"
	}
	local index
	if days > 0 then
		index = 4
	elseif hours > 0 then 
		index = 3
	elseif minutes > 0 then
		index = 2
	else
		index = 1
	end
	local str = ""
	for i=index,1,-1 do 
		local new_str
		if style == 1 then
			new_str = string.format("%i" .. b[i],a[i])
		else
			new_str = string.format("%i",a[i])
		end
		if str ~= "" then 
			new_str = space_char .. new_str
		end
		str = str .. new_str
	end
	
	return str
end

--loggers
Console.blt_log = Console.blt_log or _G.log
function Console:Log(info,params)
	local _info = tostring(info)
	if self._window_instance then 
		params = type(params) == "table" and params or {}
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
				color = self:GetColorByName(_type)
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
	
	local should_blt_log = self.settings.log_blt_enabled
	if should_blt_log then 
		self.blt_log(string.format(managers.localization:text("menu_consolemod_window_log_prefix_str"),_info))
	end
	
end
_G.Log = callback(Console,Console,"Log")
Console.log = Console.Log

function Console:Print(...)
	return self:Log(self.table_concat({...}," "))
end
_G.Print = callback(Console,Console,"Print")

function Console:BLT_Print(...)
	log(self.table_concat({...}," "))
end
_G._print = callback(Console,Console,"BLT_Print")

function Console:LogTable(obj,threaded)
	if not obj then 
		local err_col = self:GetColorByName("error")
		self:Log("Error: LogTable(" .. tostring(obj) .. ")",{color = err_col})
		return
	end
	if threaded then
		return self:LogTable_Threaded(obj)
	else
		return self:_LogTable(obj)
	end
end
_G.logall = callback(Console,Console,"LogTable")

function Console:_LogTable(obj)
	for k,v in pairs(obj) do 
		local data_type = type(v)
		local color = self:GetColorByName(data_type,"misc")
		self:Log("[" .. tostring(k) .. "] : [" .. tostring(v) .. "]",{color = color})
	end
end

function Console:LogTable_Threaded(obj,desc)
	--create thread to log table
	self:AddCoroutine(callback(self,self,"_LogTable",obj),{
		desc = desc or "LogTable(" .. tostring(obj) .. ")",
		priority = nil,
		paused = false
	})
end
_G.logall2 = callback(Console,Console,"LogTable_Threaded")

function Console:_LogTable_Threaded(obj,t,dt)
--generally best used to log all of the properties of a Class:
--functions;
--and values, such as numbers, strings, tables, etc.

	
	--i don't really know how else to do this
--todo save this as a global to Console so that i can create and delete examples but save their references
	if not obj then 
		local err_col = self:GetColorByName("error")
		self:Log("Error: LogTable(" .. tostring(obj) .. ")",{color = err_col})
		return
	end
	for k,v in pairs(obj) do 
		local data_type = type(v)
			--[[
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
			--]]
		local color = self:GetColorByName(data_type,"misc")
		self:Log("[" .. tostring(k) .. "] : [" .. tostring(v) .. "]",{color = color})
		coroutine.yield()
	end
end
--core functionality

function Console:SearchTable(tbl,s,case_sensitive,threaded)
	local function cb()
		return self:_SearchTable(tbl,s,case_sensitive,threaded)
	end
	if threaded == false then --default true if not specified off
		cb()
	else
		self:AddCoroutine(cb,{
			desc = "Console:SearchTable(" .. tostring(tbl) .. "," .. tostring(s) .. ")",
			priority = nil,
			paused = false
		})
	end
end

function Console:_SearchTable(tbl,s,case_sensitive,threaded)
	local err_color = self:GetColorByName("error")
    s = tostring(s)
	local s_lower = case_sensitive and s or string.lower(s)
    self:Log("Searching table " .. tostring(tbl) .. " for \"" .. s .. "\"")
	local done_any = false
    if type(tbl) == "table" then 
        for k,v in pairs(tbl) do 
			local name = tostring(k)
			local name_lower = case_sensitive and name or string.lower(name)
            local msg = "TABLE"
            if string.match(name_lower,s) then
				done_any = true
                local t = type(v)
				if t == "function" then 
					msg = tostring(t) .. "." .. name .. "()" --" = " .. tostring(v)
				else
					msg = tostring(t) .. "." .. name .. " = " .. tostring(v)
				end
				local col = self:GetColorByName(t,"misc")
                self:Log(msg,{color = col})
				if threaded then
					local t,dt = coroutine.yield()
				end
            end
        end
    else
        self:Log("Type is not table/class!",{color = err_color})
    end
	if not done_any then 
		self:Log("No results for '" .. tostring(s) .."' in " .. tostring(tbl),{color = Color("ff4400")})
	end
end

_G.search_class = function(...)
	return Console:SearchTable(...)
end

function Console:callback_confirm_text(dialog_instance,text)
	return self:ParseTextInput(text)
end

function Console:ParseTextInput(text)
	local COMMAND_PREFIX = self.PREFIXES.COMMAND
	local ALIAS_PREFIX = self.PREFIXES.ALIAS
	local command_repeat = string.rep(COMMAND_PREFIX,2)
	if string.sub(text,1,2) == command_repeat then
		--special repeat command "//" executes previous input
		local input_log = self._input_log
		if #input_log > 0 then
			local data = input_log[#input_log]
			text = data.input
		else
			self:Log("Error: No command history!")
		end
	end
	
	local first_char = string.sub(text,1,1)
	if first_char == ALIAS_PREFIX then
		local _text = string.sub(text,2) --remove alias signifier
		local a,b = string.find(_text,"[^%s]*")
		if a then
			local alias_token = string.sub(_text,a,b)
			local alias = self:GetAlias(alias_token)
			if alias then
				text = self.string_replace(_text,a,b,alias)
				first_char = string.sub(text,1,1)
			end
			--alias cannot trigger special repeat command "//"
		else
			--only command name (no params)
			local alias = self:GetAlias(_text)
			if alias then 
				text = alias
			end
		end
	end
	
	if first_char == COMMAND_PREFIX then 
		self.blt_log(self.settings.window_prompt_string .. text)
		local func = self:InterpretCommand(text)
		self:AddToInputLog({
			input = text,
			func = func
		})
		if func then 
			return func()
		end
	elseif string.gsub(text,"%s","") ~= "" then
		self.blt_log(self.settings.window_prompt_string .. text)
		local func = self:InterpretLua(text)
		local result
		if func then 
			result = {blt.pcall(func)}
			local success = table.remove(result,1)
			if success then 
				--continue
			else
				local err = table.remove(result,1)
				self:Log(err,{color=self:GetColorByName("error")})
			end
		end
		self:AddToInputLog(
			{
				input = text,
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
				local color = self:GetColorByName(_type)
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
end

function Console:InterpretLua(s)
	local func,err = loadstring(s)
	if not func then 
		local err_color = self:GetColorByName("error")
		self:Log("Error loading chunk:",{color=err_color})
		self:Log(err,{color=err_color})
	end
	return func,err
end

function Console:InterpretCommand(raw_cmd_string)
	if not raw_cmd_string then 
		return nil,"string expected, got nil"
	end
	--command string must start with "/"
	
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
	local cmd_string_no_cmd_name = cmd_string

	--escape any characters that need escaping (ironically this step only needs to be performed on the substitutes)
	local esc = self.string_escape_magic_characters
	
	
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
		if params_start > 2 then
			args_string = string.sub(cmd_string_subbed,1,params_start - 2) --extra indices for the space and hyphen
		else
			args_string = ""
		end
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
			local p = table.deep_map_copy(possible_params)
			if param_data.confirmed then
				--exact match already exists
			else
				for i=#p,1,-1 do 
					local possible_param_name = p[i]
					local search_key = "^" .. self.string_escape_magic_characters(param_data.name) .. ""
					if (string.find(possible_param_name,search_key)) then
						--
					else
						table.remove(p,i)
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
			local new = esc(sub_data.s2,to)

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
	local meta_params = {
		raw_input = raw_cmd_string, --store this here and pass it to any command to allow custom parsing
		cmd_string = cmd_string_no_cmd_name
	}
	
	if command_data.func then 
		return function ()
			return command_data.func(cmd_params,args_string,meta_params)
		end
	end
	--[[
	elseif command_data.str then 
		local func,err = loadstring(command_data.str)
		if func then
			command_data.func = func
			return pcall(func,cmd_params,args_string,meta_params)
		elseif err then
			self:Log(err)
		end
		self:AddToInputLog({
			input = raw_cmd_string,
			func = func
		})
	end
	--]]
end

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
	
	local restart_data = self._restart_data
	if restart_data then
		local restart_t = restart_data.restart_t
		if restart_t then --time at which heist will restart
			local time_left = math.ceil(restart_t - t) --seconds left to restart
			
			local message_t = restart_data.message_t or -1
			local MESSAGE_INTERVAL = 1
			if message_t <= t then 
				restart_data.message_t = t + MESSAGE_INTERVAL 
				local out_str = string.format(managers.localization:text("menu_consolemod_cmd_restart_dialog_countdown"),time_left)
				local out_col = self:GetColorByName("system")
				self:Log(out_str,{color = out_col})
				
				if not restart_data.is_silent then
					local sender_str = managers.localization:text("menu_consolemod_window_log_prefix_short")
					if managers.chat then
						managers.chat:_receive_message(1,sender_str,out_str, out_col)
						managers.chat:send_message(managers.chat._channel_id, sender_str or managers.network.account:username() or "Nobody",out_str)
					end
				end
			end
			
			if time_left <= 0 then --do actual restart here
				if not restart_data.noclose then
					self:HideConsoleWindow()
				end
				self._restart_data = nil
				
				if game_state_machine and game_state_machine:current_state_name() == "menu_main" then
					if setup and setup.load_start_menu then
						setup:load_start_menu()
					end
				elseif managers.game_play_central then
					if Global.game_settings.single_player or (managers.network and managers.network:session():is_host()) then
						managers.game_play_central:restart_the_game()
					end
				else
					self._restart_data = nil
				end
				
			end
		elseif restart_data.duration then
			--start timer
			self._restart_data.restart_t = t + restart_data.duration
		else
			--invalid data
			self._restart_data = nil
		end
	end
	self:UpdateKeybinds(t,dt)
	self:UpdateCoroutines(t,dt)
	self:UpdateTrackers(t,dt)
end

function Console:GetColorByName(color_name,fallback)
	local color
	local color_setting_name = color_name and self.color_data[color_name]
	if not color_setting_name then 
		if fallback ~= false then
			fallback = "misc"
		end
		if type(fallback) == "userdata" then 
			color = fallback
		else
			color_setting_name = self.color_data[fallback]
		end
	end
	if color_setting_name then
		local color_setting = self.settings[color_setting_name]
		color = Color(string.format("%06x",color_setting or 0))
	end
	return color
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
			local result = {blt.vm.dofile(self._autoexec_menustate_path)}
			if #result > 0 then
				self:Print(unpack(result))
			end
		end
	end
end

--commands

function Console.string_escape_magic_characters(s,to)
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
	local a,b
	if to then 
		a = 1
		b = 2
	else
		a = 4
		b = 2
	end
	for _,character in pairs(escape_magic_chars) do 
		local _s = s
		s = string.gsub(s,string.rep("%",a) .. character,string.rep("%",b) .. character)
	end
	return s
end




function Console:cmd_help(params,subcmd,meta_params)
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

function Console:cmd_weaponname(params,args,meta_params)
	self:AddCoroutine(function(t,dt)
			self:_cmd_weaponname(params,args,meta_params)
		end,{
		desc = meta_params.raw_input,
		priority = nil,
		paused = false
	})
end

function Console:_cmd_weaponname(params,name,meta_params)
	params = type(params) == "table" and params or {}
	local results = {}
	if name == "" then
		name = params.name
	end
	local name_lower = name and string.lower(name)
	
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
		local bm_id = managers.weapon_factory:get_factory_id_by_weapon_id(weapon_id)
		local bm_id_lower = bm_id and string.lower(bm_id)
		if name_id then
			localized_name = managers.localization:text(name_id)
			localized_name_lower = string.lower(localized_name)
		end
		
		if name then
			if localized_name and string.find(localized_name_lower,name_lower) then
				--pass
			elseif string.find(weapon_id_lower,name_lower) then
				--pass
			elseif bm_id_lower and string.find(bm_id_lower,name_lower) then
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
		self:Log(tostring(weapon_id) .. " / " .. tostring(localized_name or "UNKNOWN") .. " / " .. tostring(bm_id))
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
				local t,dt = coroutine.yield()
			end
		end
	end
	self:Log("---Search ended.")
	return results
end

function Console:cmd_partname(params,args,meta_params)
	self:AddCoroutine(function(t,dt)
			self:_cmd_partname(params,args,meta_params)
		end,{
		desc = meta_params.raw_input,
		priority = nil,
		paused = false
	})
end

function Console:_cmd_partname(params,name,meta_params)
	params = type(params) == "table" and params or {}
	local results = {}
	local _type = params.type
	local weapon_id = params.weapon_id or params.weapon
	local list_weapons = params.blueprint
	local allow_npc_weapons = params.npcs
	local perks = params.perks
	local perks_list
	
	local search_feedback_str = "--- Searching for"
	if name and name ~= "" then 
		search_feedback_str = search_feedback_str .. " part: [" .. tostring(name) .. "]"
	else
		search_feedback_str = search_feedback_str .. " all parts"
	end
	if _type then 
		search_feedback_str = search_feedback_str .. " of attachment type [" .. tostring(_type) .. "]"
	end
	if perks then
		perks_list = string.split(perks," ")
		if #perks_list > 0 then
			search_feedback_str = search_feedback_str .. " with weapon perks [" .. perks .. "]"
		else
			perks_list = nil
		end
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
			if perks_list then
				if not part_data.perks then 
					--no perks on this attachment
					return false
				else
					for _,perk_name in pairs(perks_list) do 
						if not table.contains(part_data.perks,string.lower(perk_name)) then 
							return false
						end
					end
				end
			end
			if name then 
				if localized_name and string.find(string.lower(localized_name),string.lower(name)) then 
					--found
				elseif string.find(string.lower(part_id),string.lower(name)) then 
					--found
				else
					return false
				end
			end
			return true
		end
	end
	local use_weapons
	if weapon_id then
		local bm_id = managers.weapon_factory:get_factory_id_by_weapon_id(weapon_id)
		local bm_weapon_data = bm_id and tweak_data.weapon.factory[bm_id]
		if bm_weapon_data and bm_weapon_data.uses_parts then
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
	
	table.sort(results)
	
	for _,part_id in ipairs(results) do 
		local part_data = tweak_data.weapon.factory.parts[part_id]
		local localized_name = part_data.name_id and managers.localization:text(part_data.name_id)
		self:Log(tostring(part_id) .. " / " .. tostring(localized_name or "UNKNOWN"))
		local t,dt = coroutine.yield()
		if list_weapons then 
			for bm_id,weapon_data in pairs(tweak_data.weapon.factory) do 
				if weapon_data.uses_parts and table.contains(weapon_data.uses_parts,part_id) then 
					local weapon_id = managers.weapon_factory:get_weapon_id_by_factory_id(bm_id)
					local localized_weapon_name = weapon_id and managers.weapon_factory:get_weapon_name_by_weapon_id(weapon_id)
					if localized_weapon_name or allow_npc_weapons then
						self:Log("    - " .. tostring(bm_id) .. " / " .. tostring(weapon_id) .. " / " .. tostring(localized_weapon_name or "UNKNOWN"))
						local t,dt = coroutine.yield()
					end
				end
			end
		end
	end
	
	self:Log("---Search ended.")
	return results
end

function Console:cmd_restart(params,args,meta_params)
	local timer_str = args == "" and params.timer or args
	local noclose = params.noclose and true or false --if instant restart and not noclose, close the console window
	local is_silent = params.silent and true or false
	local timer = tonumber(timer_str)
	local message_t
	
	local is_in_menu = game_state_machine and game_state_machine:current_state_name() == "menu_main"

	if timer_str == "cancel" or timer_str == "stop" then
		--assuming the player doesn't want to do anything if their timer is "stop"
		self._restart_data = nil
		return
	end
	
	if self._restart_data then
		--cancel any current restart
		if not is_silent then 
			local sender_str = managers.localization:text("menu_consolemod_window_log_prefix_short")
			local out_str = managers.localization:text("menu_consolemod_cmd_restart_dialog_cancelled")
			if managers.chat then
				local color = self:GetColorByName("system")
				managers.chat:_receive_message(1,sender_str,out_str, color)
				managers.chat:send_message(managers.chat._channel_id, sender_str or managers.network.account:username() or "Nobody",out_str)
			end
		end
	end
	
	if timer then
		message_t = 0
	else
		timer = -1
		message_t = nil -- 0-second countdowns are not very helpful
	end
	
	
	if managers.game_play_central then
		if Global.game_settings.single_player then 
			--allowed to restart
		elseif managers.network then 
			if params.vote and managers.vote and managers.vote:option_vote_restart() then 
				managers.vote:restart()
				--[[
				local votemanager = managers.vote
				if not votemanager._stopped then
					votemanager._callback_type = "restart"
					votemanager._callback_counter = TimerManager:wall():time() + tonumber(timer)		
				end
				--]]
				
				--no need to prevent closing since the restart presumably is not happening immediately
--				if not params.noclose then 
--					self:HideConsoleWindow()
--				end

				--ignore timer here
				return
			elseif managers.network:session():is_host() then
				--allowed to restart
			else
				self:Log("You cannot restart the game in which you are not the host!",{color = self:GetColorByName("error")})
				return
			end
		else
			self:Log("Invalid game state- cannot restart")
		end
	elseif is_in_menu then
			--at main menu; allowed to reload state
		--in menu- allowed to restart
	end
	
	self._restart_data = {
		duration = timer,
		message_t = message_t,
		is_silent = is_silent,
		noclose = noclose
	}
	
end

function Console:cmd_alias(params,args,meta_params)
	local do_loadstring = params.loadstring --if true, attempts to read the provided value as a chunk, instead of just storing the string value
	local noalias = params.noalias
	local raw_input = meta_params.raw_input
	local cmd_no_name = meta_params.cmd_string 
	local name_start,name_finish = string.find(args,"%w+[%w_]*") --must start with alphanum
	local var_name = name_start and string.sub(args,name_start,name_finish)
	local err_col = self:GetColorByName("error")
	
	local feedback_val,feedback_type
	local value,func,err
	local args_no_params
		
	if var_name and string.gsub(var_name,"%s","") ~= "" then
		cmd_no_name = string.sub(cmd_no_name,name_finish + 2)
		local esc_chars = {
			"'",
			'"'
		}
		local param_char = "-"
		local param_index
		local char_pair
		if cmd_no_name and string.find(cmd_no_name,"%" .. param_char) then
			for i=1,utf8.len(cmd_no_name),1 do 
				local current_char = string.sub(cmd_no_name,i,i)
				if not char_pair then
					if current_char == param_char then
						param_index = i
						break
					end
					if table.contains(esc_chars,current_char) then
						char_pair = current_char
					end
				else
					if char_pair == current_char then
						char_pair = nil
					end
				end
			end
		end
		if param_index then 
			args_no_params = string.sub(cmd_no_name,1,param_index-2) --extra index for space and param char
		else
			args_no_params = cmd_no_name
		end
		
		if do_loadstring then 
			func,err = loadstring(args_no_params)
			if func then 
				feedback_val = args_no_params
				feedback_type = type(func)
			else
				self:Log("Error loading string chunk:",{color=err_col})
				self:Log(args_no_params,{color=err_col})
				self:Log(err,{color=err_col})
				
				return
			end
		else
			if not noalias then
				value = self:replace_aliases_in_string(args_no_params)
			end
			feedback_val = value
			feedback_type = type(value)
		end
	else
		self:Log(managers.localization:text("menu_consolemod_cmd_alias_bad_name"),{color=err_col})
		return
	end
	
	if value or func then
		self:SetAlias(var_name,value,func)
	else
		self:Log(managers.localization:text("menu_consolemod_cmd_alias_bad_value"),{color=err_col})
		return
	end
	
	if feedback_val then 
		local feedback_len = utf8.len(feedback_val)
		local feedback_col = self:GetColorByName(feedback_type,"misc")
		self:Log(string.format(managers.localization:text("menu_consolemod_cmd_alias_assigned"),tostring(feedback_val),self.PREFIXES.ALIAS .. var_name),{color_ranges = {{start = 1,finish = feedback_len + 1,color=feedback_col}}})
	end
end

function Console:cmd_unalias(params,args,meta_params)
--	local _args = string.split(args," ")
--	local name = params.name or args[1]
---	local raw_input = meta_params.raw_input

	local cmd_no_name = meta_params.cmd_string 
	local name_start,name_finish = string.find(args,"%w+[%w_]*") --must start with alphanum
	local var_name = string.sub(args,name_start,name_finish)
	if var_name and string.gsub(var_name,"%s","") ~= "" then
--		cmd_no_name = string.sub(cmd_no_name,name_finish + 2)
		self:RemoveAlias(var_name)
	end
	
end

function Console:cmd_clear(params,args,meta_params) --clears the console
	local clear_output = params.output_clear
	local clear_input = params.input_clear
	if self._window_instance then 
		self._window_instance:clear_history_text()
	end
	if clear_output then 
		for i=#self._output_log,1,-1 do 
			self._output_log[i] = nil
		end
		self:SaveOutputLog()
	end
	if clear_input then 
		for i=#self._input_log,1,-1 do 
			self._input_log[i] = nil
		end
		self:SaveInputLog()
	end
end

function Console:cmd_echo(params,s,meta_params)
	s = self:replace_aliases_in_string(s)
	self:Log(s)
end

function Console:cmd_skillname(params,args,meta_params)
	local name = args ~= "" and args or params.name
	
	local results = {}
	if not name or name == "" then
		local err_color = self:GetColorByName("error")
		self:Log("Error: /skillname: No name provided!",{color=err_color})
		return 
	end
	local skill_names
	self:Log("--- Searching for skill: " .. name .. "...")
	
	for skill_id,data in pairs(tweak_data.skilltree.skills) do 
		if type(data) == "table" and (data.name_id or data.desc_id) then 
			local found
			local localized_name = data.name_id and managers.localization:text(data.name_id) or "[NAME ERROR]"
			local localized_desc = data.desc_id and managers.localization:text(data.desc_id) or "[DESC ERROR]"
			if string.find(string.lower(skill_id),name) then 
				results[skill_id] = results[skill_id] or {name_id = data.name_id,title = localized_name}
			elseif string.find(string.lower(localized_name),name) then 
				results[skill_id] = results[skill_id] or {name_id = data.name_id,title = localized_name}
			elseif data.name_id and string.find(data.name_id,name) then 
				results[skill_id] = results[skill_id] or {name_id = data.name_id,title = localized_name}
			elseif string.find(string.lower(localized_desc),name) then 
				results[skill_id] = results[skill_id] or {name_id = data.name_id,title = localized_name,desc = localized_desc}
			elseif data.desc_id and string.find(data.desc_id,name) then 
				results[skill_id] = results[skill_id] or {name_id = data.name_id,title = localized_name,desc_id = data.desc_id}
			end
		end
	end
	
	local formatted = {
		title = "Name: $title",
		name_id = "name_id: $name_id",
		desc_id = "desc_id: $desc_id",
		desc = "Description: $desc",
		upgrade_id = "upgrade_id = $upgrade_id"
	}
	
	for skill_id,skill_name_data in pairs(results) do 
		self:Log("Skill: " .. tostring(skill_id),{color=Color.yellow})
		for key,value in pairs(skill_name_data) do 
			if formatted[key] then 
				local _value = string.gsub(value,"\n"," | ")
				self:Log(string.gsub(formatted[key],"$" .. key,_value),{color=Color(1,0.5,0.25)})
			end
		end
	end
	
	self:Log("---Search ended.")
	return results
end

function Console:cmd_info()
	local mm_key = NetworkMatchMakingSTEAM._BUILD_SEARCH_INTEREST_KEY
	self:Log("CURRENT INFO:",{color=Color.yellow})
	
	self:Log(string.format("Application version: %s",Application:version()))
	self:Log(string.format("Matchmaking key: %s",mm_key))
	
	local console_version_blt = "unknown"
	local console_blt_mod = BLT.Mods:GetModByName("Developer Console")
	if console_blt_mod then
		console_version_blt = console_blt_mod:GetVersion()
	end
	self:Log(string.format("Console version (SBLT): %s",console_version_blt))
	
	--[[
	local console_version_beardlib = "unknown"
	if ConsoleCore then
		for _,_module in ipairs(ConsoleCore._modules) do 
			if _module._name == "AssetUpdates" then
				console_version_beardlib = _module.version
				break
			end
		end
	end
	self:Log(string.format("Console version (BeardLib): %s",console_version_beardlib))
	--todo mod hash?
	--]]
	
end

--keybinds

function Console:cmd_bind(params,args,meta_params)
	local key_raw = args or params.key
	local key_name = key_raw
	local _args = string.split(args," ")
	--lookup
	--self:Log("Warning: key name not recognized. Keybind may fail to execute.")
	
	local _type = params.type
	local action = params.action --the payload string or action name
	local list = params.list or _args[1] == "list" or not action
	
	local repeat_delay
	if params.repeat_delay then 
		repeat_delay = tonumber(params.repeat_delay)
	end
	local hold
	if params.hold then 
		hold = tonumber(params.hold)
	end
	local allow_in_chat = params.chatenabled
	local allow_in_console = params.consoleenabled
	
	local err_color = self:GetColorByName("error")
	local device 
	
	if string.find(key_raw,"mouse ") then 
		device = self.INPUT_DEVICES.MOUSE
		if not string.find(key_raw,"wheel") then 
			key_name = string.sub(key_raw,7)
		end
	else
		device = self.INPUT_DEVICES.KEYBOARD
	end
	
	if list then 
		if key_name and key_name ~= "" then
			local id,keybind_data = self._custom_keybinds[key_raw]
			if keybind_data then
				--list specified keybind
				self:Log(string.format(
						"Key: %s | Raw Key: %s | Type: %s | Action: %s | Repeat Delay: %s | Hold: %s | Device: %s",
						tostring(id),
						tostring(keybind_data.key_raw),
						tostring(keybind_data.type),
						tostring(keybind_data.action),
						keybind_data.repeat_delay and string.format("%0.2f",keybind_data.repeat_delay) or "-",
						keybind_data.hold and string.format("%0.2f",keybind_data.hold) or "-",
						tostring(keybind_data.device)
					)
				)
			else
				self:Log(string.format("No key found by id [%s]",key_name))
			end
		else
			--list all keybinds
			local done_any = false
			for id,keybind_data in pairs(self._custom_keybinds) do 
				done_any = true
				self:Log(string.format(
						"Key: %s | Raw Key: %s | Type: %s | Action: %s | Repeat Delay: %s | Hold: %s | Device: %s",
						tostring(id),
						tostring(keybind_data.key_raw),
						tostring(keybind_data.type),
						tostring(keybind_data.action),
						keybind_data.repeat_delay and string.format("%0.2fs",keybind_data.repeat_delay) or "-",
						keybind_data.hold and string.format("%0.2fs",keybind_data.hold) or "-",
						tostring(keybind_data.device)
					)
				)
			end
			if not done_any then 
				self:Log("No keybinds found.")
			end
		end
	else
		local data = {
			key_name = key_name,
			key_raw = key_raw,
			device = device,
			type = _type,
			action = action,
			hold = hold,
			repeat_delay = repeat_delay,
			allow_chat = allow_in_chat,
			allow_console = allow_in_console
		}
		local success,err = self:_cmd_bind(key_raw,data)
		
		if success then
			self:Log("Bound [" .. tostring(key_raw) .. "] to [" .. tostring(action) .. "]")
		elseif err then
			self:Log("Error: Unable to parse keybind action:",{color=err_color})
			self:Log(err,{color=err_color})
		end
		
		self:SaveKeybinds()
	end
end

function Console:_cmd_bind(key_raw,data)
	local func,err
	if data.type == "chunk" then
		func,err = self:InterpretLua(data.action)
	elseif data.type == "command" then
		func,err = self:InterpretCommand(data.action)
	else
		--providing a type is much more efficient,
		--since that way the function can be cached,
		--instead of forcing the game to load the chunk on every keybind execution.
		--but, if absolutely necessary, keybinds can be used to substitute direct console input.
		--this is also the only way to use the special repeat command "//" with keybinds.
		func = function()
			self:ParseTextInput(data.action)
		end
	end
	
	if func then
		data.func = func
		self._custom_keybinds[key_raw] = data
		return true
	else
		return false,err
	end
end

function Console:cmd_unbind(params,args,meta_params)
	local err_color = self:GetColorByName("error")
	if args == "all" or params.key == "all" then
		local num_done = 0
		for k,_ in pairs(self._custom_keybinds) do 
			self._custom_keybinds[k] = nil
			num_done = num_done + 1
		end
		self:Log(string.format("Removed all keybinds! (%i)",num_done))
	else
		if self._custom_keybinds[args] then 
			self._custom_keybinds[args] = nil
			self:Log(string.format("Unbound key [%s]",args))
		else
			self:Log(string.format("No keybind found by key name [%s]",args),{color=err_color})
		end
	end
	self:SaveKeybinds()
end

function Console:UpdateKeybinds(t,dt)
	local chat_focused
	if managers then 
		if managers.hud and managers.hud:chat_focus() then
			chat_focused = true
		elseif managers.menu_component and managers.menu_component:input_focut_game_chat_gui() then
			chat_focused = true
		end
	end

	local console_focused = Console._window_instance:is_focused()

	for _,data in pairs(self._custom_keybinds) do 
		local key = data.key_name
		if chat_focused and not data.allow_chat then 
			return
		elseif console_focused and not data.allow_console then
			return
		end
		local down
		if data.device == 1 then --mouse button
			down = Input:mouse():down(Idstring(key))
		elseif data.device == 2 then --keyboard key
			down = Input:keyboard():down(Idstring(key))
		elseif data.device == 3 then --controller axis/button (not yet implemented)
--			local wrapper_index = managers.controller:get_default_wrapper_index()
--			local controller_index = managers.controller:get_controller_index_list(wrapper_index)
--			local controller = Input:controller(controller_index)
--			down = controller:down(Idstring(key))
		end
		
		if down then
			local do_action
			local is_press
			
			local cache = self._input_cache[key]
			if not cache then
				cache = {
					start_t = t
				}
				if data.hold then
					cache.next_t = t + data.hold
				elseif data.repeat_delay then
					cache.next_t = t + data.repeat_delay 
				end
				self._input_cache[key] = cache
				
				is_press = true
			end
			
			if cache.next_t then
				if cache.next_t < t then
					do_action = true
					if data.repeat_delay then
						cache.next_t = cache.next_t + data.repeat_delay
					else
						cache.next_t = nil
					end
				end
			elseif is_press then
				do_action = true
			end

			if do_action then
				if data.func then 
					data.func()
				end
			end
		else
			self._input_cache[key] = nil
		end
	end
end

--coroutine/thread management

function Console:cmd_thread(params,args,meta_params)

	--acceptable formats:
	--		/thread subcmd i
	--		/thread subcmd -n i
	--		/thread i
	
	local _args = string.split(args," ")
	local subcmd = _args[1]
	local id = _args[2] or params.number or params.id
	
	local err_color = self:GetColorByName("error")
	
	if id == "last" then
		id = self._coroutine_counter
	end
	
	if params.list or subcmd == "list" then 
		subcmd = "list"
	elseif params.pause or subcmd == "pause" then
		subcmd = "pause"
	elseif params.resume or subcmd == "resume" then 
		subcmd = "resume"
	elseif params.kill or subcmd == "kill" or params.remove or subcmd == "remove" or params.stop or subcmd == "stop" then
		subcmd = "kill"
	elseif tonumber(subcmd) then
		id = tonumber(subcmd)
		subcmd = "list"
	else
		self:Log("Invalid subcmd: " .. tostring(subcmd),{color=err_color})
		return
	end
	
	
	if subcmd == "list" then
		if id then
			local index,thread_data = self:GetCoroutine(id)
			if thread_data then
				local age_raw = os.time() - thread_data.creation_timestamp
				local age_str = self.format_time(age_raw,{style=1,divider=":"})
				
				self:Log(string.format("ID: %i | DESC: %s | AGE: %s | RUNTIME: %0.2fs | PAUSED: %s",
					thread_data.id,
					thread_data.desc or "",
					age_str,
					thread_data.clock,
					tostring(thread_data.paused and true or false)
				))
			else
				--no thread found
				self:Log(string.format("Could not find a thread with id [%s]",id),{color=err_color}) 
				return
			end
		else
			if #self._threads > 0 then 
				local order = {}
				local st = {}
				local spacing = {1,1,1,1,1}
				local max_spacing = {9,32,16,9,9}
				local align = {1,1,2,2,1}
				local div_char = "|"
				local space_char = " "
					
				for i,thread_data in ipairs(self._threads) do 
					local id_str = string.format("%i",thread_data.id)
					local desc_str = thread_data.desc or ""
					local age_str = self.format_time(os.time() - thread_data.creation_timestamp,{style=1})
					local clock_str = string.format("%0.2fs",thread_data.clock)
					local paused_str = tostring(thread_data.paused and true or false)
					spacing[1] = math.clamp(spacing[1],utf8.len(id_str),max_spacing[1])
					spacing[2] = math.clamp(spacing[2],utf8.len(desc_str),max_spacing[2])
					spacing[3] = math.clamp(spacing[3],utf8.len(age_str),max_spacing[3])
					spacing[4] = math.clamp(spacing[4],utf8.len(clock_str),max_spacing[4])
					spacing[5] = math.clamp(spacing[5],utf8.len(paused_str),max_spacing[5])
					st[i] = {
						id_str,
						desc_str,
						age_str,
						clock_str,
						paused_str
					}
					table.insert(order,i)
				end
				table.sort(order,function(a,b)
					if self._threads[a].id < self._threads[b].id then 
						return true
					else
						return false
					end
				end)
				
				local header_columns = {
					"ID",
					"DESC",
					"AGE",
					"RUNTIME",
					"PAUSED"
				}
				local header_str = ""
				for j=1,5,1 do 
					local str = header_columns[j]
					local str_len = utf8.len(str)
					spacing[j] = math.max(spacing[j],str_len)
					local h = spacing[j] - str_len
					local pad_left = string.rep(space_char,math.floor(h/2))
					local pad_right = string.rep(space_char,math.ceil(h/2))
					header_str = header_str .. (
						pad_left
						..
						str
						..
						pad_right
						..
						div_char
					)
				end
				self:Log(header_str)
				
				for _,i in ipairs(order) do 
					local f_s = ""
					for j=1,5,1 do 
						local str = st[i][j]
						local str_len = utf8.len(str)
						if str_len > spacing[j] then
							str = string.sub(str,1,spacing[j])
							str_len = spacing[j]
						end
						local h = spacing[j] - str_len
						local pad_left,pad_right
						if align[j] == 3 then --right
							if h > 1 then
								pad_right = string.rep(space_char,1)
								pad_left = string.rep(space_char,h-1)
							else
								pad_right = ""
								pad_left = string.rep(space_char,h)
							end
						elseif align[j] == 2 then --center (left bias)
							pad_left = string.rep(space_char,math.floor(h/2))
							pad_right = string.rep(space_char,math.ceil(h/2))
						else --left
							if h > 1 then
								pad_left = string.rep(space_char,1)
								pad_right = string.rep(space_char,h-1)
							else
								pad_left = ""
								pad_right = string.rep(space_char,h)
							end
						end
						f_s = f_s .. (
							pad_left
							..
							str
							..
							pad_right
							..
							div_char
						)
					end
					self:Log(f_s)
				end
			else
				self:Log("There are no registered threads.")
			end
		end
	else
		if id then
			local cb
			local fail_msg_sing
			local done_msg_plur
			local done_msg_sing
			if subcmd == "pause" then --pause
				cb = function(index,thread_data)
					if not thread_data.paused then
						thread_data.paused = true
						return true
					end
				end
				fail_msg_sing = "Thread [%i] is already paused."
				done_msg_sing = "Paused thread [%i]."
				done_msg_plur = "Paused all threads. (%i paused / %i total)"
			elseif subcmd == "resume" then --resume
				cb = function(index,thread_data)
					if thread_data.paused then
						thread_data.paused = false
						return true
					end
				end
				fail_msg_sing = "Thread [%i] is not paused."
				done_msg_sing = "Resumed thread [%i]."
				done_msg_plur = "Resumed all threads. (%i resumed / %i total)"
			elseif subcmd == "kill" then --kill
				cb = function(index,thread_data)
					return (table.remove(self._threads,index) and true or false)
				end
				fail_msg_sing = "Thread [%i] does not exist."
				done_msg_sing = "Removed thread [%i]."
				done_msg_plur = "Disposed of multiple threads. (%i disposed / %i total)"
			end
			
			if id == "all" then
				local num_done = 0
				local num_total = #self._threads
				for i = num_total,1,-1 do 
					if cb(i,self._threads[i]) then
						num_done = num_done + 1
					end
				end
				self:Log(string.format(done_msg_plur,num_done,num_total))
			else
				local index,thread_data = self:GetCoroutine(id)
				if thread_data then
					if cb(index,thread_data) then
						self:Log(string.format(done_msg_sing,index))
					else
						self:Log(string.format(fail_msg_sing,index),{color=err_color})
					end
				else
					self:Log(string.format("Could not find a thread with id [%s]",id),{color=err_color})
					return
				end
			end
		else
			self:Log("You must supply a thread id!",{color=err_color})
		end
	end
end

function Console:UpdateCoroutines(t,dt)
	
	for i=#self._threads,1,-1 do 
		local data = self._threads[i]
		local tid = data.id
		local co = data.thread
		local state = coroutine.status(co)
		if state and state ~= "dead" then
			if state == "suspended" then 
				if not data.paused then 
					data.clock = data.clock + dt
					local success,err = coroutine.resume(co,t,dt)
					if not success then 
						data.paused = true
						local err_color = self:GetColorByName("error")
						self:Log("Paused execution of thread " .. tostring(tid))
						self:Log(err,{color=err_color})
						--table.remove(self._threads,i)
					end
				end
			end
		elseif self.settings.console_autocull_dead_threads then
			table.remove(self._threads,i)
		end
	end
end

function Console:AddCoroutine(func,params)
--desc is separate from id;
--id is a unique identifier automatically generated/incremented by Console,
--but desc is a human-readable string representing the command or chunk being executed
	local id = self._coroutine_counter + 1
	
	local err_col = self:GetColorByName("error")
	if type(func) ~= "function" then 
		self:Log("Error: bad function type for arg #1 " .. tostring(func) .. " [" .. tostring(func) .. "], should be function",{color=err_col})
		return
	end
	
	params = type(params) == "table" and params or {}
	local desc = params.desc
	local priority = params.priority
	local paused = params.paused
	
	local index = #self._threads + 1
	--get priority; larger priorities are executed first
	--if no priority is specified, add to the end of the stack
	if priority then
		for i=1,#self._threads,-1 do 
			local data = self._threads[i]
			if priority <= data.priority then 
				index = i
				break
			end
		end
	end
	
	
	local thread,err = coroutine.create(func)
	if thread then
		local new_thread_data = {
			id = id,
			desc = desc,
			thread = thread,
			func = func,
			priority = priority,
			clock = 0,
			creation_timestamp = os.time(),
			paused = paused
			--, max_time = 10,
			--max_executions = 0,
		}
--		self:Log("Adding " .. tostring(thread) .. " with id " .. tostring(id))
		self._coroutine_counter = id
		table.insert(self._threads,index,new_thread_data)
	end
end

function Console:GetCoroutine(id)
	id = id and tonumber(id)
	if id then
		for i,thread_data in ipairs(self._threads) do 
			if thread_data.id == id then 
				return i,thread_data
			end
		end
	end
end

--alias management

function Console:replace_aliases_in_string(s)
	--todo escape quotes or "\" 
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
					local result = {
						blt.pcall(
							function()
								value = data.get_value()
							end
						)
					}
					local success = table.remove(result,1)
					if success then 
					else
						local err = table.remove(result,1)
						self:Log(err,{color=self:GetColorByName("error")})
					end
				else
					value = data.value
				end
				s = string.gsub(s,alias,tostring(value))
			end
		end
	end
	return s
end

function Console:SetAlias(id,val,func)
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


--hud trackers

function Console:CreateTrackerHUD()
	if managers.gui_data then
		self._ws = self._ws or managers.gui_data:create_fullscreen_workspace()
		self._panel = self._panel or self._ws:panel()
		
		for _,data in pairs(self._trackers) do 
			self:ConfigTracker(data.name,data.params,data.text_params,data.bitmap_params)
		end
		
	end
end

function Console:NewTracker(tracker_name,params,text_params,bitmap_params)
	local tracker_panel
	local tracker_text,tracker_bitmap
	local i = #self._trackers + 1
	params = type(params) == "table" and params or {}
	if alive(self._panel) then
		tracker_panel = self._panel:panel({
			name = name,
			layer = 1
		})
			
		local upd_bitmap_func = params.upd_bitmap_func 
		local _bitmap_params = { --defaults
			name = "bitmap",
			texture = "guis/textures/icon_loading",
			texture_rect = nil,
			color = Color.white,
			rotation = nil,
			render_template = nil,
			blend_mode = "normal",
			wrap = nil, --"wrap" or "clamp",
			x = 50,
			y = 50 * i,
--			w = 32,
--			h = 32,
			visible = true
		}
		if type(bitmap_params) == "table" then
			for k,v in pairs(bitmap_params) do 
				_bitmap_params[k] = v
			end
		else
			_bitmap_params.visible = false
			_bitmap_params.w = 16
			_bitmap_params.h = 16
		end
		tracker_bitmap = tracker_panel:bitmap(_bitmap_params)
		
		local _text_params = { --defaults
			name = "label",
			text = "empty",
			text_id = nil,
			x = tracker_bitmap:right(),
			y = 50 * i,
			align = "left",
			vertical = "top",
			font = "fonts/font_bitstream_vera_mono",
			font_size = 32,
			selection_color = Color.black,
			color = Color.white,
			wrap = false,
			monospace = false,
			rotation = nil,
			render_template = nil,
			blend_mode = "normal",
			visible = true,
			layer = 1
		}
		if type(text_params) == "table" then
			for k,v in pairs(text_params) do 
				_text_params[k] = v
			end
		end
		tracker_text = tracker_panel:text(_text_params)
	end
	
	
	table.insert(self._trackers,i,{
		name = tracker_name,
		params = params,
		panel = tracker_panel,
		text_obj = tracker_text,
		text_params = _text_params,
		bitmap_obj = tracker_bitmap,
		bitmap_params = _bitmap_params,
		upd_func = params.upd_func,
		upd_bitmap_func = params.upd_bitmap_func,
		upd_text_func = params.upd_text_func
	})
end

function Console:GetTracker(name)
	for i,data in pairs(self._trackers) do 
		if data.name == name then 
			return i,data
		end
	end
end

function Console:SetTracker(val,name)
	name = name or "default"
	local i,data = self:GetTracker(name)
	if data then
		if alive(self._panel) then
			data.text_params = data.text_params or {}
			data.text_params.text = tostring(val)
			if alive(data.text_obj) then
				data.text_obj:set_text(tostring(val))
				return
				--todo default rotate text on update: if alive bitmap obj then rotate bitmap obj
			end
		end
	else
		self:NewTracker(name,nil,{text = tostring(val)},nil)
	end
end
Console.SetTrackerValue = function(self,a,b) --legacy support
	return self:SetTracker(b,a)
end

function Console:ConfigTracker(name,params,text_params,bitmap_params)
	local i,data = self:GetTracker(name)
	if data then
		if type(text_params) == "table" then
			local _text_params = { --defaults
				name = "label",
				text = "",
				text_id = nil,
				x = 50,
				y = 50 * i,
				align = "left",
				vertical = "top",
				font = "fonts/font_bitstream_vera_mono",
				font_size = 32,
				selection_color = Color.black,
				color = Color.white,
				wrap = false,
				monospace = false,
				rotation = nil,
				render_template = nil,
				blend_mode = "normal",
				visible = true,
				layer = 1
			}
			data.text_params = data.text_params or {}
			for k,v in pairs(text_params) do 
				_text_params[k] = v
				data.text_params[k] = v
			end
			
			if alive(data.text_obj) then
				data.text_obj:config(text_params)
			else
				data.text_obj = data.panel:text(_text_params)
			end
		end
		if type(bitmap_params) == "table" then
			local _bitmap_params = { --defaults
				name = "bitmap",
				texture = "guis/textures/icon_loading",
				texture_rect = nil,
				color = Color.white,
				rotation = nil,
				render_template = nil,
				blend_mode = "normal",
				wrap = nil, --"wrap" or "clamp",
				x = 50,
				y = 50 * i,
	--			w = 32,
	--			h = 32,
				visible = true
			}
			data.bitmap_params = data.bitmap_params or {}
			for k,v in pairs(bitmap_params) do 
				_bitmap_params[k] = v
				data.bitmap_params[k] = v
			end
			
			if alive(data.bitmap_obj) then
				data.bitmap_obj:config(bitmap_params)
			else
				data.bitmap_obj = data.panel:bitmap(_bitmap_params)
			end
		end
		return true
	end
	return false
end

function Console:RemoveTracker(name)
	local i,data = self:GetTracker(name)
	if data then
		if alive(self._panel) and alive(data.panel) then
			self._panel:remove(data.panel)
		end
		return table.remove(self._trackers,i)
	end
end

function Console:UpdateTrackers(t,dt)
	if alive(self._panel) then
		for _,data in pairs(self._trackers) do 
			if data.upd_func then
				data.upd_func(data,t,dt)
			end
			if data.upd_text_func and alive(data.tracker_label) then 
				data.upd_text_func(data.tracker_label,t,dt)
			end
			if data.upd_bitmap_func and alive(data.tracker_bitmap) then 
				data.upd_bitmap_func(data.tracker_bitmap,t,dt)
			end
		end
	elseif not self._ws then 
		self:CreateTrackerHUD()
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
		local state = not self._window_instance:is_focused()
		if state then 
			self:ShowConsoleWindow()
		else
			self:HideConsoleWindow()
		end
	end
end


--i/o
function Console:SaveInputLog() --only used to clear log; normally, use append mode
	local file = io.open(self._input_log_file_path,"w+")
	if file then
		file:write(self.table_concat(self._input_log,"\n"))
		file:close()
	end
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
						if func then
						elseif err then
							--silent fail- if these are logged, the output log would probably balloon in size
							--add errors to table internally?
							func = nil
						end
					end
					self._input_log[i] = {
						input = line,
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
	if self.settings.log_input_enabled then
		table.insert(self._input_log,#self._input_log+1,data)
		local s = data.input
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


function Console:SaveOutputLog() --only used to clear log; normally, use append mode
	if not self._is_reading_log then
		local file = io.open(self._output_log_file_path,"w+")
		if file then
			file:write(self.table_concat(self._output_log,"\n"))
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
	if self.settings.log_output_enabled then 
		table.insert(self._output_log,#self._output_log+1,s)
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

function Console:SaveKeybinds()
	local keybinds = {}
	
	for key_name,keybind_data in pairs(self._custom_keybinds) do 
		table.insert(keybinds,#keybinds + 1,{
			key_name = keybind_data.key_name,
			key_raw = keybind_data.key_raw,
			type = keybind_data.type,
			action = keybind_data.action,
			device = keybind_data.device,
			hold = keybind_data.hold,
			repeat_delay = keybind_data.repeat_delay,
			allow_console = keybind_data.allow_console,
			allow_chat = keybind_data.allow_chat
		})
	end
	
	self._lip.save(self._keybinds_path,keybinds)
end

function Console:LoadKeybinds()
	if SystemFS:exists( Application:nice_path(self._keybinds_path,true) ) then 
		local config_from_ini = self._lip.load(self._keybinds_path)
		for _,keybind_data in pairs(config_from_ini) do 
			self:_cmd_bind(keybind_data.key_raw,{
				key_name = keybind_data.key_name,
				key_raw = keybind_data.key_raw,
				type = keybind_data.type,
				action = keybind_data.action,
				device = keybind_data.device,
				hold = keybind_data.hold,
				repeat_delay = keybind_data.repeat_delay,
				allow_console = keybind_data.allow_console,
				allow_chat = keybind_data.allow_chat
			})
		end
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
	Console:LoadSettings()
	

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
				if Console._window_instance and Console._window_instance:is_focused() then 
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
	Console:LoadKeybinds()
	
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
Hooks:Add("GameSetupPausedUpdate","dcc_update_gamesetuppaused",callback(Console,Console,"Update","GameSetupPausedUpdate"))


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