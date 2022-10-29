--log(tostring(Console.console_window_menu_id))
--log(tostring(Console._menu_node))

local instance = Console and Console._window_instance

_G.logall = callback(Console,Console,"LogTable")
_G.Print = callback(Console,Console,"Print")
_G.Log = callback(Console,Console,"Log")


--instance._confirm_func = callback(instance, instance, "button_pressed_callback")

Console:ToggleConsoleWindow()
do return end

instance:_confirm_func()
do return end







Console:AddFonts()
Console:LoadFonts()
 
do return end

	local hud = managers.menu_component and managers.menu_component._fullscreen_ws:panel()
	if alive(hud:child("test")) then 
		hud:remove(hud:child("test"))
	end
	local font = hud:bitmap({
		name = "test",
		text = "12346789 abcdefghijkl",
		font = "fonts/font_bitstream_vera_mono",
		font_size = 32,
		x = 36,
		y = 36,
		layer = 1,
		color = Color.white,
		alpha = 1
	})
	asdr = font

 do return end






do return end
QuickMenu:new(
"herllo","goodbfyue",
	{
		{
			text = "heldffd",
			is_cancel_button = true
		}
	}
,true)
managers.system_menu:force_close_all()

managers.menu:open_menu(Console.console_window_menu_id)
managers.menu:open_node(Console.console_window_menu_id)

--Print(Console._window_instance._input_text)
--Console._window_instance._input_text:set_kern(1.5)
--[[
	local hud = managers.menu_component and managers.menu_component._fullscreen_ws:panel()
	if alive(hud:child("test")) then 
		hud:remove(hud:child("test"))
	end
	local font = hud:text({
		name = "test",
		text = "12346789 abcdefghijkl",
		font = "fonts/font_bitstream_vera_mono",
		font_size = 32,
		x = 36,
		y = 36,
		layer = 1,
		color = Color.white,
		alpha = 1
	})
	asdr = font

--]]