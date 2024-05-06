if not _G.BeardLib then
	dofile(ModPath .. "Core.lua")
end

local orig_toggle_chatinput = MenuManager.toggle_chatinput
function MenuManager:toggle_chatinput(...)
	if Console._window_instance and Console._window_instance:is_focused() then
		return
	end
	return orig_toggle_chatinput(self,...)
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
	MenuCallbackHandler.callback_dcc_reset_window_pos = function(self)
		
		Console.settings.window_x = Console.default_settings.window_x
		Console.settings.window_y = Console.default_settings.window_y
		Console.settings.window_w = Console.default_settings.window_w
		Console.settings.window_h = Console.default_settings.window_h
		
		
		if Console._window_instance then
			Console._window_instance._panel:set_position(Console.settings.window_x,Console.settings.window_y)
		end
		
		Console:SaveSettings()
	end
	MenuCallbackHandler.callback_dcc_console_window_font_size = function(self,item)
		Console.settings.window_font_size = tonumber(item:value())
		
		Console:SaveSettings()
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

