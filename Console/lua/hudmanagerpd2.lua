Hooks:PostHook(HUDManager,"_setup_player_info_hud_pd2","commandprompt_setup_workspace",function(self)
	self:_create_commandprompt()
end)

function HUDManager:_create_commandprompt()
	if not self:alive(PlayerBase.PLAYER_INFO_HUD_PD2) then 
		return
	end	
	Console._ws = managers.gui_data:create_fullscreen_workspace()
	local ws = Console._ws:panel()
	
	local orig_hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2).panel
	
	local console_w = orig_hud:w()
	local console_h = orig_hud:h() --720
	
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
		y = 0,
		w = console_w,
		h = console_h - (v_margin + font_size)
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
		h = h_margin + 12, --increased with each Log()
		layer = 100
	})
	
	local history_size_debug = command_history_panel:rect({
		name = "history_size_debug",
		layer = 98,
		visible = false,
		color = Console.quality_colors.arc:with_alpha(0.5)
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
		layer = 102,
		w = 12,
		h = 12,
		y = 0,
		color = Color.white:with_alpha(0.7)
	})
	
	local scroll_block_bottom = console_base:rect({	
		name = "scroll_block_bottom",
		layer = 102,
		w = 12,
		h = 12,
		y = console_h - (v_margin + font_size + 12),
		color = Color.white:with_alpha(0.7)
	})
	
	local scroll_bg = console_base:rect({
		name = "scroll_bg",
		layer = 99,
		w = 12,
		h = console_h - (font_size + v_margin),
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
--	self:create_dot_test(ws)
	
end

--[[

function HUDManager:create_dot_test(base)
	local tube_base = base:panel({
		name = "dot_test_1",
		layer = 1,
		w = 400,
		h = 400,
		x = base:right() - 400,
		y = base:bottom() - 400
	})
	Console._tube_base = tube_base
	local tube_bg = tube_base:rect({
		name = "tube_bg",
		color = Color.red,
		visible = false,
		alpha = 0.5
	})
	
	--these should be odd for symmetry with "even" patterns
	local ROWS = 16 --34 max
	local COLUMNS = 16 --62
	Console._dot_last_t = 2
	Console._dot_last_pattern = 1 --for sequential pattern mode

	Console._ROW_SIZE = ROWS
	Console._COLUMN_SIZE = COLUMNS
	
	Console._patterns_odd = {
		{
			[1] = {
				3,4,5,6
			},
			[2] = {
				3,6
			},
			[3] = {
				3,4,5,6
			},
			[4] = {
				0,1,2,3,4,5,6,7,8,9
			},
			[5] = {
				0,2,3,4,5,6,7,9
			},
			[6] = {
				0,2,3,4,5,6,7,9
			},
			[7] = {
				0,1,2,3,4,5,6,7,8,9
			},
			[8] = {
				3,4,5,6
			},
			[9] = {
				3,6
			},
			[10] = {
				3,4,5,6
			}
		},
		{
			[1] = {
				3,4,5,6
			},
			[2] = {
				1,3,4,5,6,8
			},
			[3] = {
				3,4,5,6
			},
			[4] = {
				0,1,2,3,4,5,6,7,8,9
			},
			[5] = {
				0,1,2,3,6,7,8,9
			},
			[6] = {
				0,1,2,3,6,7,8,9
			},
			[7] = {
				0,1,2,3,4,5,6,7,8,9
			},
			[8] = {
				3,4,5,6
			},
			[9] = {
				1,3,4,5,6,8
			},
			[10] = {
				3,4,5,6	
			}
		},
		{
			[1] = {
				2,3,4,5,6,7
			},
			[2] = {
				1,3,4,5,6,8
			},
			[3] = {
				0,2,4,5,7,9
			},
			[4] = {
				0,1,3,4,5,6,8,9
			},
			[5] = {
				0,1,2,3,6,7,8,9
			},
			[6] = {
				0,1,2,3,6,7,8,9
			},
			[7] = {
				0,1,3,4,5,6,8,9
			},
			[8] = {
				0,2,4,5,7,9
			},
			[9] = {
				1,3,4,5,6,8
			},
			[10] = {
				2,3,4,5,6,7
			}
		},
		{
			[1] = {
				2,4,5,7
			},
			[2] = {
				1,4,5,8
			},
			[3] = {
				0,2,7,9
			},
			[4] = {
				3,4,5,6
			},
			[5] = {
				0,1,3,6,8,9
			},
			[6] = {
				0,1,3,6,8,9
			},
			[7] = {
				3,4,5,6
			},
			[8] = {
				0,2,7,9
			},
			[9] = {
				1,4,5,8
			},
			[10] = {
				2,4,5,7
			}
		},
		{
			[5] = {4,5},
			[6] = {4,5}
		},
		{
			[1] = {
				3,4,5,6
			},
			[2] = {
				3,6
			},
			[3] = {
				3,4,5,6
			},
			[4] = {
				0,1,2,3,4,5,6,7,8,9
			},
			[5] = {
				0,2,3,4,5,6,7,9
			},
			[6] = {
				0,2,3,4,5,6,7,9
			},
			[7] = {
				0,1,2,3,4,5,6,7,8,9
			},
			[8] = {
				3,4,5,6
			},
			[9] = {
				3,6
			},
			[10] = {
				3,4,5,6
			}
		}
	}
	
	Console._patterns = { --these count from 0; should all be 8x8
		dot = { --8x8 even
			[1] = {
				3,4
			},
			[2] = {
				2,3,4,5
			},
			[3] = {
				1,2,5,6
			},
			[4] = {
				0,1,3,4,6,7
			},
			[5] = {
				0,1,3,4,6,7
			},
			[6] = {
				1,2,5,6
			},
			[7] = {
				2,3,4,5
			},
			[8] = {
				3,4
			}
		},
		dot_i = { --8x8 odd
			[1] = {
				4,5
			},
			[2] = {
				3,4,5,6
			},
			[3] = {
				2,3,6,7
			},
			[4] = {
				1,2,4,5,7,8
			},
			[5] = {
				1,2,4,5,7,8
			},
			[6] = {
				2,3,6,7
			},
			[7] = {
				3,4,5,6
			},
			[8] = {
				4,5
			}
		},
		lotus = { --10x10 even
			[1] = {
				2,5
			},
			[2] = {
				2,3,4,5
			},
			[3] = {
				0,1,3,4,6,7
			},
			[4] = {
				1,2,3,4,5,6
			},
			[5] = {
				1,2,3,4,5,6
			},
			[6] = {
				0,1,3,4,6,7
			},
			[7] = {
				2,3,4,5
			},
			[8] = {
				2,5
			}
		},
		x = { --even 8x8
			[2] = {
				2,5
			},
			[3] = {
				1,3,4,6
			},
			[4] = {
				2,5
			},
			[5] = {
				2,5
			},
			[6] = {
				1,3,4,6
			},
			[7] = {
				2,5
			}
		},
		x_i = { --odd 8x8
			[2] = {
				3,6
			},
			[3] = {
				2,4,5,7
			},
			[4] = {
				3,6
			},
			[5] = {
				3,6
			},
			[6] = {
				2,4,5,7
			},
			[7] = {
				3,6
			}
		}
	--	superintendent = { --10x10 odd
			
	--}
	
	}
	
	Console._tubes = {
		
	}

	local function even(n)
		return math.floor(n/2) == (n/2)
	end
	
	local function create_tube(num) --so this is sideways. yep.
		local angle = 45
	
		local row = 1 + (math.floor(num / COLUMNS))
		local column = 1 + (num % (COLUMNS))
		local even_c = even(column)
		local even_r = even(row)
		if even_c then 
			if even_r then 
				angle = -135
			else
				angle = 135
			end
		else
			if even_r then 
				angle = -45
			else
				angle = 45
			end			
		end
		
		local texture = false and tweak_data.hud_icons.wp_arrow.texture or "guis/textures/test_blur_df"
		local texture_rect = tweak_data.hud_icons.wp_arrow.texture_rect
		
		local h_space = 20
		local w_space = 20
		
		local new_tube = tube_base:bitmap({
			name = "tube_" .. row .. "_" .. column,
			texture = texture,
--			texture_rect = texture_rect,
			w = 16,
			h = 4,
			x = w_space * column,
			y = h_space * row,
			layer = 1,
			alpha = 1,
			rotation = angle,
			blend_mode = "add",
			color = Color(0,0.3,0.9)
		})
		local debug_tube = tube_base:text({
			name = "debug_text_" .. num,
			text = tostring(num),
			font = tweak_data.hud.medium_font,
			font_size = 16,
			x = w_space * column,
			y = h_space * row,
			layer = 2,
			visible = false,
			alpha = 0.7,
			color = Color.white
		})
		
		return new_tube
	end
	
	local function neighbor(direction,number)
	--todo actually test the damned thing
		local result = number
		if string.find(direction,"e") then 
			if ((number+1) / COLUMNS) == math.floor((number+1)/COLUMNS) then 
				return --no neighbors; already at right border
			else
				result = result + 1
			end
		elseif string.find(direction,"w") then 
			if (number / COLUMNS) == math.floor(number/COLUMNS) then 
				return --no neighbors; already at left border
			else
				result = result - 1
			end
		end
		
		if string.find(direction,"n") then
			if number < COLUMNS then
				return --no neighbors; already at top border
			else
				result = result - ROWS
			end
		elseif string.find(direction,"s") then
			if number > (COLUMNS * (ROWS - 1)) then 
				return --no neighbors; already at bottom border
			else
				result = result + ROWS
			end
		end
		return result
	end

		
	for i = 0,(ROWS * COLUMNS) - 1 do 
		Console._tubes[i] = {tube = create_tube(i),delay = 0}
	end
	
	local function get_tube(num)
		return Console._tubes[i].tube
	end
	local function get_random_tube(num)
		return math.random(COLUMNS * ROWS)
	end
	
end

function HUDManager:_set_dot_pattern(pattern_name)
	local pattern = Console._patterns[pattern_name]
	if pattern then 
		local changed_tubes = {}
		local center_r = math.floor((Console._ROW_SIZE - 8) / 2) + 1
		local center_c = math.floor((Console._COLUMN_SIZE - 8) / 2) + 1
	--do row and column offsets based on grid size
		for row,c in pairs(pattern) do 
			for _,column in pairs(c) do 
				local tube_name = "tube_" .. (row + center_r) .. "_" .. (column + center_c)
				local tube = Console._tube_base:child(tube_name)
				if tube then 
					changed_tubes[tube_name] = true
					tube:stop()
					tube:animate(callback(self,self,"_animate_dot_tube_on_flicker"))
				end
			end
		end
		
		for k,v in pairs(Console._tubes) do 
			if v.tube then 
				if not changed_tubes[v.tube:name()]then 
					v.tube:stop()
					v.tube:animate(callback(self,self,"_animate_dot_tube_off_flicker"))
				end
			end
		end
	end
end

function HUDManager:_set_dot_sequence()
	Console._dot_last_pattern = math.max(1,(1 + Console._dot_last_pattern) % #Console._patterns_odd)
	--managers.hud:_set_dot_sequence(1)
	local pattern_name = Console._dot_last_pattern

	local pattern = Console._patterns_odd[pattern_name or ""]
	if pattern then 
		Log("doing pattern " .. pattern_name)
		local changed_tubes = {}
		local center_r = math.floor((Console._ROW_SIZE - 10) / 2)
		local center_c = math.floor((Console._COLUMN_SIZE - 10) / 2) + 1
	--do row and column offsets based on grid size
		for row,c in pairs(pattern) do 
			for _,column in pairs(c) do 
				local tube_name = "tube_" .. (row + center_r) .. "_" .. (column + center_c)
				local tube = Console._tube_base:child(tube_name)
				if tube then 
					changed_tubes[tube_name] = true
					tube:stop()
					tube:animate(callback(self,self,"_animate_dot_tube_on_flicker_two")) --non-flicker is broken. great
				end
			end
		end
		
		for k,v in pairs(Console._tubes) do 
			if v.tube then 
				if not changed_tubes[v.tube:name()]then 
					v.tube:stop()
					v.tube:animate(callback(self,self,"_animate_dot_tube_off_flicker_two"))
				end
			end
		end
	end
end


function HUDManager:_animate_dot_tube_off(tube) --todo exponential interpolation
	
	local MAX_ALPHA = 0.2

	local duration = 1
	local elapsed = 0
	local tube_color = tube:color()
	local desired_color = Color((0.1 * math.random()),0.25 + (math.random() * 0.15),0.9 + (0.1 * math.random()))
	local tube_alpha = tube:alpha()
	while elapsed < duration do 
		local dt = coroutine.yield()
		elapsed = elapsed + dt
		tube:set_alpha(tube_alpha + ((MAX_ALPHA - tube_alpha) * (elapsed / duration)))
		tube:set_color(interp_col(tube_color,desired_color,elapsed/duration))
	end
	tube:set_alpha(MAX_ALPHA)
	
end

function HUDManager:asdfsdf_an_on(tube) --why doesn't this work
	if (not Console._selected_tube) or (math.random() > 0.75) then
		Console._selected_tube = tube --todo reset tube at some point
	end
	local duration = 1
	local elapsed = 0
	local tube_alpha = tube:alpha()
	local tube_color = tube:color()
	local MIN_ALPHA = 0.95
	local desired_color = Color(math.random(155)/255,math.random(209)/255,math.random(255)/255)
	local rate = 1.4
	
	while elapsed < duration do 
		Console:SetTrackerValue("trackera",elapsed)
		local dt = coroutine.yield()
		Console:SetTrackerValue("trackerb",dt)
		elapsed = elapsed + dt
		tube:set_alpha(tube_alpha + ((MIN_ALPHA - tube_alpha) * (elapsed / duration)))
		tube:set_color(interp_col(tube_color,desired_color,elapsed/duration))
	end
	Log("elapsed: " .. tostring(elapsed) .. "," .. "duration: " .. tostring(duration))
	tube:set_alpha(1)
	
end
function HUDManager:_animate_dot_tube_on(tube)
	if (not Console._selected_tube) or (math.random() > 0.75) then
		Console._selected_tube = tube --todo reset tube at some point
	end
	local t = 1
	local tube_alpha = tube:alpha()
	local tube_color = tube:color()
	local MIN_ALPHA = 0.95
	local desired_color = Color(math.random(155)/255,math.random(209)/255,math.random(255)/255)
	local rate = 1.4
	
	while t > 0 do 
		local dt = coroutine.yield()
		t = t - dt
		Console:SetTrackerValue("trackera",t)
		Console:SetTrackerValue("trackerb",dt)
		tube:set_alpha(tube_alpha + ((MIN_ALPHA - tube_alpha) * t))
		tube:set_color(interp_col(tube_color,desired_color,t))
	end
	tube:set_alpha(1)
	
end

function HUDManager:_animate_dot_tube_on_flicker_two(tube) --reduced delay; used for sequence
--	tube:set_visible(true)
	if (not Console._selected_tube) or (math.random() > 0.75) then
		Console._selected_tube = tube --todo reset tube when
	end
	local MIN_ALPHA = 0.95
	local delay = math.random() / 4
	local tube_alpha = tube:alpha()
	local desired_color = Color(math.random(155)/255,math.random(209)/255,math.random(255)/255)
	local rate = 2
	
	while tube_alpha < MIN_ALPHA do --slight flicker when alpha jumps from MIN_ALPHA to 1
		local dt = coroutine.yield()
		if delay <= 0 then 
			tube_alpha = (tube_alpha + 0.15) * rate
			tube:set_alpha(tube_alpha)
--			Log(tube:name() .. "," .. dt)
			tube:set_color(interp_col(tube:color(),desired_color,dt * 1.5)) --gradually progress toward "lit" color; effectively a logarithmic function
		else
			delay = delay - dt
		end
	end
	tube:set_alpha(1)
	
end

function HUDManager:_animate_dot_tube_off_flicker_two(tube) --reduce delay; used for sequence
--	tube:set_visible(true)
	
	local MAX_ALPHA = 0.2
	local delay = math.random() / 4

	local current_color = tube:color()
	local desired_color = Color((0.1 * math.random()),0.25 + (math.random() * 0.15),0.9 + (0.1 * math.random()))
	local tube_alpha = tube:alpha()
	while tube_alpha > MAX_ALPHA do
		local dt = coroutine.yield()
		if delay <= 0 then 
			tube_alpha = tube_alpha * 0.5
			tube:set_alpha(tube_alpha)
--			tube:set_color(
		else
			delay = delay - dt
		end
	end
	tube:set_alpha(MAX_ALPHA)
	
end

function HUDManager:_animate_dot_tube_on_flicker(tube)
--	tube:set_visible(true)
	if (not Console._selected_tube) or (math.random() > 0.75) then
		Console._selected_tube = tube --todo reset tube when
	end
	local MIN_ALPHA = 0.95
	local delay = math.random()
	local tube_alpha = tube:alpha()
	local desired_color = Color(math.random(155)/255,math.random(209)/255,math.random(255)/255)
	local rate = 1.2
	
	while tube_alpha < MIN_ALPHA do --slight flicker when alpha jumps from MIN_ALPHA to 1
		local dt = coroutine.yield()
		if delay <= 0 then 
			tube_alpha = tube_alpha * rate
			tube:set_alpha(tube_alpha)
--			Log(tube:name() .. "," .. dt)
			tube:set_color(interp_col(tube:color(),desired_color,dt * 1.5)) --gradually progress toward "lit" color; effectively a logarithmic function
		else
			delay = delay - dt
		end
	end
	tube:set_alpha(1)
	
end

function HUDManager:_animate_dot_tube_off_nice(tube)
--	tube:set_visible(true)
	
	local MAX_ALPHA = 0.15
	local delay = (math.random() * 1.25) + 1
	
	local tube_alpha = tube:alpha()
	while tube_alpha > MAX_ALPHA do
		local dt = coroutine.yield()
		if delay <= 0 then 
			tube_alpha = tube_alpha * 0.9
			tube:set_alpha(tube_alpha)
		else
			delay = delay - dt
		end
	end
	tube:set_alpha(0.2) --normal max alpha
	
end

function HUDManager:_animate_dot_tube_off_flicker(tube)
--	tube:set_visible(true)
	
	local MAX_ALPHA = 0.2
	local delay = math.random()

	local current_color = tube:color()
	local desired_color = Color((0.1 * math.random()),0.25 + (math.random() * 0.15),0.9 + (0.1 * math.random()))
	local tube_alpha = tube:alpha()
	while tube_alpha > MAX_ALPHA do
		local dt = coroutine.yield()
		if delay <= 0 then 
			tube_alpha = tube_alpha * 0.8
			tube:set_alpha(tube_alpha)
--			tube:set_color(
		else
			delay = delay - dt
		end
	end
	tube:set_alpha(MAX_ALPHA)
	
end


function HUDManager:_set_dot_all_off()
	for k,v in pairs(Console._tubes) do 
		if v.tube then 
			v.tube:stop()
			v.tube:animate(callback(self,self,"_animate_dot_tube_off_flicker"))
		end
	end
end

function HUDManager:_set_dot_all_on()
	for k,v in pairs(Console._tubes) do 
		if v.tube then 
			v.tube:stop()
			v.tube:animate(callback(self,self,"_animate_dot_tube_on_flicker"))
		end
	end
end

function HUDManager:_set_dot_off_nice() --todo randomly select highlighted tube when turn on, instead of random method
	--get one from somewhere in the middle four rows/columns
--	local row = math.random(4)
--	local column = math.random(4)
--	local selected = math.random(#Console._tubes)
	for k,v in pairs(Console._tubes) do 
		if v.tube then 
			v.tube:stop()
			if Console._selected_tube and Console._selected_tube:name() == v.tube:name()  then 
				v.tube:animate(callback(self,self,"_animate_dot_tube_off_nice"))
			else
				v.tube:animate(callback(self,self,"_animate_dot_tube_off_flicker"))
			end
		end
	end
	
end

local function interp_col(one,two,percent)

--percent is [0,1]
	percent = math.clamp(percent,0,1)
	
--color 1
	local r1 = one.red
	local g1 = one.green
	local b1 = one.blue
	
--color 2
	local r2 = two.red
	local g2 = two.green
	local b2 = two.blue

--delta
	local r3 = r1 - r2
	local g3 = g1 - g2
	local b3 = b1 - b2
	
	return Color(r1 + (r3 * percent),g1 + (g3 * percent), b1 + (b3 * percent))	
end

Hooks:PostHook(HUDManager,"update","reach_dot_update",function(self,t,dt)
--[
	if t > Console._dot_last_t then
		Console._dot_last_t = t + 3
		local function random_index (tbl) --i hate everything about this
			local length = 0
			for k,v in pairs(tbl) do 
				length = length + 1
			end
			local chosen = math.ceil(math.random(length))
			local n = 0
			for j,w in pairs(tbl) do 
				n = n + 1
				if n == chosen then 
					return j
				end
			end
		end
		local p = random_index(Console._patterns)
		if p then 
			self:_set_dot_pattern(p)
		end
	end
	--]
	if t > Console._dot_last_t then
		Console._dot_last_t = t + 1
		--		self:_set_dot_sequence(Console._dot_last_pattern)
		self:_set_dot_sequence()
	end
end)
--]]
--[[
--todo: test neighbors()
--make neighbors return a table?
--test with coroutine.yield()
--add animate widgets for toggle, flicker, and delay
-- determine "center" from number

ripple test:

local droplet = math.random(ROWS * COLUMNS) --must be integer

--style 1: reach out in every direction; each direction will propogate that direction only
--style 2: reach out in each cardinal direction (nsew); on the first iteration of each direction, spread may propogate with up to one degree of deviation
	N may become N, NE, or NW
	E may become E, NE, or SE
		etc.

--additional:
	delay may be randomized for each individual iteration.
	desired formations may be calculated with horizontal symmetry



--]]


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