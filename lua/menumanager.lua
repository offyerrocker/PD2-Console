
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
