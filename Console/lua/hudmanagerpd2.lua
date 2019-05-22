Hooks:PostHook(HUDManager,"_setup_player_info_hud_pd2","commandprompt_setup_workspace",function(self)
	self:_create_commandprompt()
end)

function HUDManager:_create_commandprompt()
	if not self:alive(PlayerBase.PLAYER_INFO_HUD_PD2) then 
		return
	end	
	Console._ws = managers.gui_data:create_fullscreen_workspace()
	local ws = Console._ws:panel()
	
	local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2).panel
	
	local console_w = hud:w()
	local console_h = hud:h()
	
	local font_size = Console:GetFontSize()
	
	local h_margin = Console.h_margin
	
	local v_margin = Console.v_margin
	
	local tracker_base = ws:panel({
		name = "tracker_base", --used for trackers
		visible = true
	})
	Console._tracker_panel = tracker_base
	
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
		y = font_size + v_margin,
		w = console_w,
		h = console_h - (font_size + v_margin)
	})
	
	local command_history_bg = command_history_frame:rect({
		name = "command_history_bg",
		layer = 99,
		h = console_h - (font_size + v_margin),
		visible = false, --draws in front of everything for whatever reason
		color = Color.black:with_alpha(0.1)
	})
	
	local scroll_handle = console_base:rect({
		name = "scroll_handle",
		layer = 101,
		w = 8,
		x = 2,
		h = console_h - font_size,
		color = Color.cyan
	})
	
	local scroll_bg = console_base:rect({
		name = "scroll_bg",
		layer = 99,
		w = 12,
		h = console_h - font_size,
		color = Color.white:with_alpha(0.5)
	})
	
	local command_history_panel = command_history_frame:panel({
		name = "command_history_panel",
		layer = 100
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

local function held(key) --should i even bother with holdthekey?
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

Hooks:PostHook(HUDManager,"update","update_olib_console",function(self,t,dt)
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
		if held(mwu) then --console scroll
			history:set_y(history:y() - scroll_speed)
			scroll_handle:set_h(console_h / Console.num_lines)
			scroll_handle:set_y(scroll_speed * (history:y() / (scroll_speed * Console.num_lines)))
		elseif held(mwd) then 
			history:set_y(history:y() + scroll_speed)
			scroll_handle:set_h(console_h / Console.num_lines)
			scroll_handle:set_y(scroll_speed * (history:y() / (scroll_speed * Console.num_lines)))
		end
	end
end)