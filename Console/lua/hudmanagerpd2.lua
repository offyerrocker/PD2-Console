Hooks:PostHook(HUDManager,"_setup_player_info_hud_pd2","commandprompt_setup_workspace",function(self)
	self:_create_commandprompt()
end)

--[[
Hooks:PostHook(HUDManager,"access_camera_track","commandprompt_test12",function(self,i,cam,pos)
	local name = Console._debug_hud:child("info_unit_name")
	local hp = Console._debug_hud:child("info_unit_hp")
	
	if name then 
		name:set_text(tostring(i))
	end
	if hp then 
		hp:set_text(tostring(cam))
	end
	local herp = Console:GetTrackerElementByName("herp")
	herp = herp or Console:CreateTracker("herp")
	
	
	herp:set_text(tostring(pos))
	
	local derp = Console:GetTrackerElementByName("derp")
	derp = derp or Console:CreateTracker("derp")
	
	local result = self._workspace:world_to_screen(cam,pos)
	Console:Log("result: " .. tostring(result),{color = Color.green})
	derp:set_text(result)
	
	
	
end)

--]]

function HUDManager:_create_commandprompt()
	if not self:alive(PlayerBase.PLAYER_INFO_HUD_PD2) then 
		return
	end	
	Console._ws = managers.gui_data:create_fullscreen_workspace()
	local ws = Console._ws:panel()
	
	local orig_hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2).panel
	
	local console_w = orig_hud:w()
	local console_h = orig_hud:h()
	
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
		y = font_size + v_margin,
		w = console_w,
		h = console_h - (font_size + v_margin + v_margin)
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
		h = 32, --increased with each Log()
		layer = 100
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
		layer = 100,
		w = 12,
		h = 12,
		y = 20,
		color = Color.white:with_alpha(0.7)
	})
	
	local scroll_block_bottom = console_base:rect({	
		name = "scroll_block_bottom",
		layer = 100,
		w = 12,
		h = 12,
		y = 700,
		color = Color.white:with_alpha(0.7)
	})
	
	local scroll_bg = console_base:rect({
		name = "scroll_bg",
		layer = 99,
		w = 12,
		h = console_h - font_size,
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
	
end


--[[

Hooks:PostHook(HUDManager,"update","update_olib_console",function(self,t,dt)

--if selected unit then update marker to unit

	local panel = Console._panel
	local scroll_handle = panel:child("scroll_handle")
	--cursor blink
	local input_text = panel:child("input_text")
	local cursor = panel:child("cursor")

	local frame = panel:child("command_history_frame")
	local history = frame:child("command_history_panel")
	local font_size = Console:GetFontSize()
	local v_margin = Console.v_margin
	local console_h = frame:h()
	local mwu = "mouse wheel up"
	local mwd = "mouse wheel down"
	local scroll_speed = Console:GetScrollSpeed()
	if Console._focus then 
		Console:upd_caret(t)
		Console:update_key_down(input_text,Console._key_pressed,t)
		local new_y
--		local y_sign
		if held(mwu) then --console scroll
			new_y = math.max(history:y() - scroll_speed,-history:h())
			
--			y_sign = math.sign(new_y)
			history:set_y(new_y)
			Console:refresh_scroll_handle()
		elseif held(mwd) then 
			new_y = math.min(history:y() + scroll_speed,0)
--			y_sign = math.sign(new_y)
			history:set_y(new_y)
			Console:refresh_scroll_handle()
		end
	end
end)

--]]