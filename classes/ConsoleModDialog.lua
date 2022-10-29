--[[ 
todo main features:


scroll function
	--lock scrollbar (disable autoscroll on new lines)

key repetition

tab key autocomplete

up/down history
mouse-selectable output text
mouse-selectable input text

--]]


--partly based on Dialog and child classes like DocumentDialog
ConsoleModDialog = ConsoleModDialog or class() --class(Dialog) --can't seem to get inheritance from this class to work

ConsoleModDialog.MOVE_AXIS_LIMIT = 0.4
ConsoleModDialog.MOVE_AXIS_DELAY = 0.4

--ConsoleModDialog.INPUT_IGNORE_DELAY_INTERVAL = 0.1
ConsoleModDialog.INPUT_REPEAT_INTERVAL_INITIAL = 0.4
ConsoleModDialog.INPUT_REPEAT_INTERVAL_CONTINUE = 0.066
ConsoleModDialog.DEFAULT_FONT_NAME = tweak_data.hud.medium_font

function ConsoleModDialog:init(manager,data)
	
--	Dialog.init(self,manager,data)
	self._manager = manager
	self._data = data or {}
--	self._font_asset_load_done = self._data.font_asset_load_done
	self._data.font_name = self._data.font_name or self.DEFAULT_FONT_NAME
	
	self._history_log = self._data.history or {
	--[[
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
	
	self._button_text_list = {}
	self:init_button_text_list()
	
	self._prompt_string = data.prompt_string or "> "
	self._input_enabled = false
	
	self._visible = false --enabled flag
	
	self._controller = self._data.controller or manager:_get_controller()
	self._confirm_func = callback(self, self, "button_pressed_callback") --automatic menu input for this is unreliable; use manual enter key detection (double input won't matter since the input text is wiped on send)
	self._cancel_func = callback(self, self, "dialog_cancel_callback")
	self._send_text_callback = self._data.send_text_callback 

	self._caret_index = 1
	
	self._caret_blink_speed = 360
	self._caret_blink_t = 0
	self._caret_blink_alpha_high = 0.95
	self._caret_blink_alpha_low = 0
	
	self._mouse_x = 0
	self._mouse_y = 0
	self._old_x = 0
	self._old_y = 0
	
	self._key_held_ids = nil
	self._key_held_t = nil
	
	self._held_object = nil
	self._mouseover_object = nil
	self._mouse_drag_x_start = nil
	self._mouse_drag_y_start = nil
	self._target_drag_x_start = nil
	self._target_drag_y_start = nil
	self._scrollbar_lock_enabled = data.scrollbar_lock_enabled or false
	self._selection_dir = 1 
	
	self._gui_done = false

	self:create_gui()
end

function ConsoleModDialog:callback_on_delayed_asset_load(font_ids)
	Console:Log("Setting font " .. tostring(font_ids))
--	do return end 
	self._input_text:set_font(font_ids)
	self._history_text:set_font(font_ids)
	self._caret:set_font(font_ids)
	self._prompt:set_font(font_ids)
	
	self._font_asset_load_done = true
end

function ConsoleModDialog:create_gui()
	local font_name = self._data.font_name
	
	if not self._font_asset_load_done then
		font_name = self.DEFAULT_FONT_NAME
	end
	
	self._fullscreen_ws = managers.gui_data:create_fullscreen_workspace()
	local parent_panel = self._fullscreen_ws:panel()
	self._parent_panel = parent_panel
	

	local font_size = self._data.font_size or 32
	
	local panel_w = 1200
	local panel_h = 600
	local panel = self._parent_panel:panel({
		name = "panel",
		visible = false,
		w = panel_w,
		h = panel_h,
		layer = 999
	})
	self._panel = panel
	panel:set_world_center(self._parent_panel:world_center())
	
	
	self._background_blur = panel:bitmap({
		name = "background_blur",
		texture = "guis/textures/test_blur_df",
		alpha = 1,
		valign = "grow",
		render_template = "VertexColorTexturedBlur3D",
		layer = 0,
		color = Color.white,
		w = panel_w,
		h = panel_h
	})
	self._background_rect = panel:rect({
		name = "background_rect",
		blend_mode = "normal",
		halign = "grow",
		alpha = 0.5,
		valign = "grow",
		layer = 0,
		color = Color.black,
		w = panel_w,
		h = panel_h
	})
	
	
	local body_margin_hor = 24
	local body_margin_ver = 24
	
	local selection_color = Color("333333")
--	local button_normal_color = Color("ffffff")
	local button_highlight_color = Color("ffd700")
	
	local close_button_w = 24
	local close_button_h = 24
	local close_button_margin = 0
	
	local scrollbar_w = 16
	local scrollbar_button_w = scrollbar_w
	local scrollbar_button_h = 16
	local vertical_margin = 100
	
	local resize_grip_w = scrollbar_button_w
	local resize_grip_h = scrollbar_button_h
	
	local top_bar_w = panel_w
	local top_bar_h = 16
	
	local top_bar = panel:rect({
		name = "top_bar",
		color = Color.white,
		alpha = 0.75,
		layer = 2,
		w = top_bar_w,
		h = top_bar_h,
		x = 0,
		y = 0
	})
	local top_grip = panel:bitmap({ --draggable top bar
		name = "top_grip",
		texture = "guis/textures/pd2/mission_briefing/assets/assets_risklevel_4",
		color = Color.blue,
		x = top_bar:x(),
		y = top_bar:y(),
		w = top_bar_w - close_button_w,
		h = top_bar:h(),
		alpha = 0.66,
		layer = 3
	})
	
	self._close_button = panel:bitmap({
		name = "close_button",
		texture = "guis/textures/pd2/mission_briefing/assets/assets_risklevel_4",
		layer = 102,
		alpha = 1,
		color = Color.red,
		x = panel:w() - (close_button_w + close_button_margin),
		y = close_button_margin,
		w = close_button_w,
		h = close_button_h
	})
--	self._close_button:set_right(panel:right() - close_button_margin)

	local resize_grip = panel:bitmap({
		name = "resize_grip",
		texture = "guis/textures/pd2/mission_briefing/assets/assets_risklevel_4",
		x = panel:w() - resize_grip_w,
		y = panel:h() - resize_grip_h,
		color = Color.green,
		w = resize_grip_w,
		h = resize_grip_h,
		layer = 102,
		alpha = 1
	})
	
	--the main stuff like the input text and history text are children of this panel
	local body = panel:panel({
		name = "body",
		x = body_margin_hor,
		y = body_margin_ver + top_bar_h,
		w = panel_w - (body_margin_hor * 2),
		h = panel_h - (body_margin_ver * 2),
		alpha = 1,
		layer = 1
	})
	self._body = body
	
	self._caret = body:text({
		name = "caret",
		layer = 103,
		x = 0,
		y = 0,
		text = "|",
		font = font_name,
		font_size = font_size,
--		monospace = true,
		color = Color.white:with_alpha(0.7)
	})
	
	self._history_text = body:text({
		name = "text",
		text = "Eorzea's unity is forged of falsehoods. Its city-states are built on deceit. And its faith is an instrument of deception. It is naught but a cobweb of lies. To believe in Eorzea is to believe in nothing. In Eorzea, the beast tribes often summon gods to fight in their stead--though your comrades only rarely respond in kind. Which is strange, is it not? Are the Twelve otherwise engaged? I was given to understand they were your protectors. If you truly believe them your guardians, why do you not repeat the trick that served you so well at Carteneau, and call them down? They will answer--so long as you lavish them with crystals and gorge them on aether. Your gods are no different than those of the beasts--eikons every one!",
--		monospace = true,
--		kern = -16,
		font = font_name,
		font_size = font_size,
		align = "left",
		vertical = "top",
		x = 0,
		y = 0,
		color = Color.white,
		wrap = true,
		alpha = 1,
		layer = 1
	})
	self._prompt = body:text({
		name = "prompt",
		text = self._prompt_string,
		x = 0,
		y = 0,
--		monospace = true,
		font = font_name,
		font_size = font_size,
		align = "left",
		vertical = "bottom",
		blend_mode = "add",
		color = Color.white,
		alpha = 0.5,
		layer = 102
	})
	
	self._input_text = body:text({
		name = "input_text",
		text = "",
--		monospace = true,
		font = font_name,
		font_size = font_size,
		align = "left",
		vertical = "bottom",
		x = 16,
		y = self._prompt:y(),
		color = Color.white,
		wrap = true,
		alpha = 1,
		layer = 100
	})
	
	self._selection_box = body:rect({
		name = "selection_box",
		x = 0,
		y = 0,
		w = 0,
		h = font_size,
		color = selection_color,
		alpha = 1,
		layer = 99,
		blend_mode = "normal"
	})
--	self._selection_box:set_bottom(panel:bottom())
	
	local scrollbar_panel = panel:panel({
		name = "scrollbar_panel"
	})
	self._scrollbar_panel = scrollbar_panel
	
	local right_align = scrollbar_panel:w() - scrollbar_w
	local bottom_align = scrollbar_panel:h() - vertical_margin
	
	local scrollbar_lock_button = scrollbar_panel:bitmap({
		name = "scrollbar_lock_button",
		color = Color.white,
		layer = 101,
		alpha = self._scrollbar_lock_enabled and 1 or 0.5,
		texture = "guis/textures/scroll_items",
		texture_rect = {
			0,16,
			16,16
		},
		x = right_align,
		y = vertical_margin,
		w = scrollbar_button_w,
		h = scrollbar_button_h
	})
	local scrollbar_button_top = scrollbar_panel:bitmap({
		name = "scrollbar_button_top",
		layer = 101,
		texture = "guis/textures/scroll_items",
		texture_rect = {
			0,0,
			15,15
		},
		w = scrollbar_button_w,
		h = scrollbar_button_h,
		x = right_align,
		y = scrollbar_lock_button:bottom()
	})
	local scrollbar_button_up = scrollbar_panel:bitmap({
		name = "scrollbar_button_up",
		layer = 101,
		texture = "guis/textures/menu_arrows",
		texture_rect = {
			0,0,
			24,24
		},
		rotation = 90,
		w = scrollbar_button_w,
		h = scrollbar_button_h,
		x = right_align,
		y = scrollbar_button_top:bottom()
	})
	local scrollbar_button_bottom = scrollbar_panel:bitmap({
		name = "scrollbar_button_bottom",
		layer = 101,
		texture = "guis/textures/scroll_items",
		texture_rect = {
			15,1,
			15,15
		},
		w = scrollbar_button_w,
		h = scrollbar_button_h,
		x = right_align,
		y = bottom_align - scrollbar_button_h
	})
	local scrollbar_button_down = scrollbar_panel:bitmap({
		name = "scrollbar_button_down",
		layer = 101,
		texture = "guis/textures/menu_arrows",
		texture_rect = {
			0,0,
			24,24
		},
		rotation = 270,
		w = scrollbar_button_w,
		h = scrollbar_button_h,
		x = right_align,
		y = scrollbar_button_bottom:top() - scrollbar_button_h
	})
	local scrollbar_handle = scrollbar_panel:bitmap({
		name = "scrollbar_handle",
		color = Color.white,
		layer = 101,
		alpha = 1,
		texture = "guis/textures/scroll_items",
		texture_rect = {
			32,0,
			11,32
		},
		x = right_align,
		y = scrollbar_button_up:bottom(),
		w = scrollbar_button_w,
		h = 100
--		h = scrollbar_panel:h() - (scrollbar_cap_top:h() + scrollbar_cap_bottom:h())
	})
	self._scrollbar_handle = scrollbar_handle
	
	local max_window_hidden_hor_margin = 64 --no more than this many pixels of the window can be horizontally hidden (above or below the edge of the screen)
	local max_window_hidden_ver_margin = 0 --no more than this many pixels of the window can be vertically hidden (above or below the edge of the screen)
	self._ui_objects = {
		--
		top_grip = {
			object = top_grip,
			mouseover_pointer = "hand", --arrow link hand grab
			mouseover_event_start_callback = nil,
			mouseover_event_stop_callback = nil,
			mouse_left_click_callback = function(o,x,y) --left click (on release)
				log("clicked selection box")
			end,
			mouse_right_click_callback = function(o,x,y) --right click (on release)
				--show context menu (click)
				log("rightclicked selection box")
			end,
			mouse_left_press_callback = function(o,x,y) --left click (on initial press)
				self._mouse_drag_x_start = x
				self._mouse_drag_y_start = y
				self._held_object = top_grip
				self._target_drag_x_start = panel:x()
				self._target_drag_y_start = panel:y()
			end,
			mouse_right_press_callback = function(o,x,y)
				--open context menu (hold)
			end,
			mouse_drag_event_callback = function(o,x,y)
				local d_x = x - self._mouse_drag_x_start
				local d_y = y - self._mouse_drag_y_start
				
				local start_x = self._target_drag_x_start
				local start_y = self._target_drag_y_start
				
				
				local to_x = start_x + d_x
				local to_y = start_y + d_y
--				local px,py = panel:world_position()
				local bw,bh = top_grip:size()
				panel:set_position(
					math.clamp( to_x, max_window_hidden_hor_margin - bw, parent_panel:w() - max_window_hidden_hor_margin ),
					math.clamp( to_y, max_window_hidden_ver_margin - bh, parent_panel:h() - (bh + max_window_hidden_ver_margin) )
				)
				
				--math.clamp(-max_window_hidden_hor_ratio,panel:w() + max_window_hidden_hor_ratio),math.clamp(to_y,-max_window_hidden_ver_ration,max_window_hidden_ver_ration))
			end
		},
		resize_grip = {
			object = resize_grip,
			mouseover_pointer = "hand",
			mouseover_event_start_callback = nil,
			mouseover_event_stop_callback = nil,
			mouse_left_click_callback = function(o,x,y)
			end,
			mouse_right_click_callback = function(o,x,y)
			end,
			mouse_left_press_callback = function(o,x,y)
			end,
			mouse_right_press_callback = function(o,x,y)
			end,
			mouse_drag_event_callback = function(o,x,y)
			end
		},
		--[[
		selection_box = {
			object = self._selection_box,
			mouse_left_click_callback = function(o,x,y)
				log("clicked selection box")
			end,
			mouse_right_click_callback = function(o,x,y)
				--show context menu
				log("rightclicked selection box")
			end,
			mouseover_pointer = "link", --arrow link hand grab
			draggable_x = false,
			draggable_y = false
		},
		--]]
		--[[
		input_text = {
			object = self._input_text,
			mouseover_pointer = "arrow",
			draggable_x = false,
			draggable_y = false,
			mouse_left_click_callback = function(o,x,y)
				--focus input box 
				log("clicked input text")
			end
		},
		--]]
		close_button = { --todo fadeout close
			object = self._close_button,
			mouseover_pointer = "link",
			mouseover_event_start_callback = function(o,x,y)
				o:set_color(button_highlight_color)
			end,
			mouseover_event_stop_callback = function(o,x,y)
				o:set_color(Color.red)
			end,
			mouse_left_click_callback = callback(self,self,"close")
		},
		scrollbar_button_down = {
			object = scrollbar_button_down,
			mouseover_pointer = "link",
			mouseover_event_start_callback = function(o,x,y)
				o:set_color(button_highlight_color)
			end,
			mouseover_event_stop_callback = function(o,x,y)
				o:set_color(Color.white)
			end,
			mouse_left_click_callback = callback(self,self,"callback_on_scrollbar_down_button_clicked")
		},
		scrollbar_button_bottom = {
			object = scrollbar_button_bottom,
			mouseover_pointer = "link",
			mouseover_event_start_callback = function(o,x,y)
				o:set_color(button_highlight_color)
			end,
			mouseover_event_stop_callback = function(o,x,y)
				o:set_color(Color.white)
			end,
			mouse_left_click_callback = callback(self,self,"callback_on_scrollbar_bottom_button_clicked")
		},
		scrollbar_button_up = {
			object = scrollbar_button_up,
			mouseover_pointer = "link",
			mouseover_event_start_callback = function(o,x,y)
				o:set_color(button_highlight_color)
			end,
			mouseover_event_stop_callback = function(o,x,y)
				o:set_color(Color.white)
			end,
			mouse_left_click_callback = callback(self,self,"callback_on_scrollbar_up_button_clicked")
		},
		scrollbar_button_top = {
			object = scrollbar_button_top,
			mouseover_pointer = "link",
			mouseover_event_start_callback = function(o,x,y)
				o:set_color(button_highlight_color)
			end,
			mouseover_event_stop_callback = function(o,x,y)
				o:set_color(Color.white)
			end,
			mouse_left_click_callback = callback(self,self,"callback_scrollbar_top_button_clicked")
		},
		scrollbar_lock_button = {
			object = scrollbar_lock_button,
			mouseover_pointer = "link",
			mouseover_event_start_callback = function(o,x,y)
				o:set_color(button_highlight_color)
			end,
			mouseover_event_stop_callback = function(o,x,y)
				o:set_color(Color.white)
			end,
			mouse_left_click_callback = callback(self,self,"callback_on_scrollbar_down_button_clicked")
		},
		scrollbar_handle = {
			object = scrollbar_handle,
			mouseover_pointer = "hand",
			mouseover_event_start_callback = nil,
			mouseover_event_stop_callback = nil,
			mouse_left_press_callback = function(o,x,y) --drag start
				self._mouse_drag_x_start = x
				self._mouse_drag_y_start = y
				self._held_object = o
				self._target_drag_x_start = o:x()
				self._target_drag_y_start = o:y()
			end,
			mouse_drag_event_callback = function(o,x,y)
				local y_min = scrollbar_button_up:bottom()
				local y_max = scrollbar_button_down:top() - scrollbar_handle:h()
				local d_x = x - self._mouse_drag_x_start
				local d_y = y - self._mouse_drag_y_start
				
				local to_y = math.clamp(self._target_drag_y_start + d_y, y_min, y_max)
				--scroll event (d_y)
				--disable autoscroll while holding bar
				o:set_y(to_y)
			end
		}
	}
	self._gui_done = true
	self._input_text:enter_text(callback(self,self,"enter_text"))
end

function ConsoleModDialog:get_mouseover_target(x,y)
	local id,target
	
	local objects = self._ui_objects
	for _id,data in pairs(objects) do 
		local object = data.object
		if alive(object) and object:inside(x,y) then 
			id = _id
			target = object
			break
		end
	end
	return id,target
end

function ConsoleModDialog:callback_scrollbar_top_button_clicked(o,x,y)
	log("clicked top")
end

function ConsoleModDialog:callback_on_scrollbar_bottom_button_clicked(o,x,y)
	log("clicked bottom")
end

function ConsoleModDialog:callback_on_scrollbar_up_button_clicked(o,x,y)
	log("clicked up")
end

function ConsoleModDialog:callback_on_scrollbar_down_button_clicked(o,x,y)
	log("clicked down")
end

function ConsoleModDialog:callback_on_scrollbar_lock_button_clicked(o,x,y)
	local state = not self._scrollbar_lock_enabled
	self._scrollbar_lock_enabled = state
	o:set_alpha(state and 1 or 0.5)
end

--function ConsoleModDialog:perform_scroll(num_lines)
--end

function ConsoleModDialog:perform_page_scroll(pages)

end

function ConsoleModDialog:release_scroll_bar()
	
end

function ConsoleModDialog:scroll_page(d_x,d_y)
	
end

function ConsoleModDialog:callback_mouse_moved(o,x,y)
--	log("moved " .. tostring(x) .. " " .. tostring(y))
	
	--get point-at target
	
	if self._is_holding_mouse_button then 
		
		local held_obj = self._held_object
		if alive(held_obj) then
			local id = held_obj:name()
			local ui_object_data = self._ui_objects[id]
			
			if ui_object_data.mouse_drag_event_callback then 
				ui_object_data.mouse_drag_event_callback(held_obj,x,y)
			end
--			if ui_object_data.pointer then 
--				managers.mouse_pointer:set_pointer_image(ui_object_data.pointer)
--			end
			managers.mouse_pointer:set_pointer_image("grab")
			
			
		else
			managers.mouse_pointer:set_pointer_image("arrow")
		end
		--[[
		local id,target = self:get_mouseover_target(x,y)
		if target then 
			managers.mouse_pointer:set_pointer_image(pointer or "arrow")
			local data = 
			--CHECK IF CAN MOVE HOR/VER
			--CHECK X/Y BOUND
			local target_name = target:name()
			if target_name == "" then 
			
			end
			
		end
		--]]
	else
		local id,mouseover_target = self:get_mouseover_target(x,y)
		local prev_mouseover_object = self._mouseover_object
		if mouseover_target ~= prev_mouseover_object then
			if alive(prev_mouseover_object) then  --stop mouseover event
				local id = prev_mouseover_object:name()
				local ui_object_data = self._ui_objects[id]
				if ui_object_data.mouseover_event_stop_callback then 
					ui_object_data.mouseover_event_stop_callback(prev_mouseover_object,x,y)
				end
			end
		end
		
		if alive(mouseover_target) then
			local ui_object_data = self._ui_objects[id]
			if mouseover_target ~= prev_mouseover_object then --start mouseover event
				self._mouseover_object = mouseover_target
				if ui_object_data.mouseover_event_start_callback then 
					ui_object_data.mouseover_event_start_callback(mouseover_target,x,y)
				end
			end
			
			if ui_object_data.mouseover_pointer then 
				managers.mouse_pointer:set_pointer_image(ui_object_data.mouseover_pointer)
			else
				managers.mouse_pointer:set_pointer_image("arrow")
			end
		else
			managers.mouse_pointer:set_pointer_image("arrow")
			self._mouseover_object = nil
		end
	end
	
	self._mouse_x = x
	self._mouse_y = y
end

function ConsoleModDialog:callback_mouse_pressed(o,button,x,y)
	log("pressed  " .. tostring(x) .. " " .. tostring(y))
	
	if button == Idstring("0") then
		self._is_holding_mouse_button = true
		local id,mouseover_target = self:get_mouseover_target(x,y)
		if mouseover_target then
			local ui_object_data = self._ui_objects[id]
			if ui_object_data.mouse_left_press_callback then
				ui_object_data.mouse_left_press_callback(mouseover_target,x,y)
			end
		end
	elseif button == Idstring("1") then 
		local id,mouseover_target = self:get_mouseover_target(x,y)
		if mouseover_target then
			local ui_object_data = self._ui_objects[id]
			if ui_object_data.mouse_right_press_callback then
				ui_object_data.mouse_right_press_callback(mouseover_target,x,y)
			end
		end
		--context menu for clicked item
	elseif button == Idstring("mouse wheel up") then 
		--scroll up
	elseif button == Idstring("mouse wheel down") then 
		--scroll down
	end
end

function ConsoleModDialog:callback_mouse_released(o,button,x,y)
--	log("released  " .. tostring(x) .. " " .. tostring(y))
	if button == Idstring("0") then
		
		local held_object = self._held_object
		if alive(held_object) then
			local id,mouseover_target = self:get_mouseover_target(x,y)
			if id then
				local ui_object_data = self._ui_objects[id]
				if mouseover_target == held_object then 
					if ui_object_data.mouse_left_click_callback then
						ui_object_data.mouse_left_click_callback(mouseover_target,x,y)
					end
				end
				if ui_object_data.mouseover_pointer then 
					managers.mouse_pointer:set_pointer_image(ui_object_data.mouseover_pointer)
				else
					managers.mouse_pointer:set_pointer_image("arrow")
				end
			end
		end
		
		self._is_holding_mouse_button = false
		self._held_object = nil
		self._target_drag_x_start = nil
		self._target_drag_y_start = nil
		self._mouse_drag_x_start = nil
		self._mouse_drag_y_start = nil

		--check pointer image
		
	end
end

function ConsoleModDialog:callback_mouse_clicked(o,button,x,y)
	log("clicked  " .. tostring(x) .. " " .. tostring(y))
end

function ConsoleModDialog:reset_caret_blink_t()
	self._caret_blink_t = Application:time()
end

function ConsoleModDialog:on_key_press(k,held)
	local input_text = self._input_text
	local current_text = input_text:text()
	
	local s,e = input_text:selection()
	if not (s and e) then 
		input_text:set_selection(0,0)
		s,e = input_text:selection()
	end
	local shift_held = self:key_shift_down()
	local ctrl_held = self:key_ctrl_down()
	local alt_held = self:key_alt_down()
	if k == Idstring("enter") or k == Idstring("return") then 
		self:button_pressed_callback()
	elseif k == Idstring("`") and not shift_held then 
	elseif k == Idstring("v") and ctrl_held then
		local clipboard = Application:get_clipboard()
		if clipboard then
			input_text:replace_text(tostring(clipboard))
		end
		self:reset_caret_blink_t()
	elseif k == Idstring("c") and ctrl_held then
		if s ~= e then
			--copy selection to clipboard, 
			Application:set_clipboard(string.sub(current_text,s,e))
			--success feedback?
		end
		self:reset_caret_blink_t()
	elseif k == Idstring("home") then 
		if shift_held then
			if self._selection_dir == -1 then 
				direction = s
			else
				direction = e
			end
			input_text:set_selection(0,direction)
		else
			input_text:set_selection(0, 0)
		end
	elseif k == Idstring("end") then 
		local current_len = string.len(current_text)
		if shift_held then
			if self._selection_dir == -1 then 
				direction = s
			else
				direction = e
			end
			input_text:set_selection(direction,current_len)
		else
			input_text:set_selection(current_len,current_len)
		end
	elseif k == Idstring("left") then
		if shift_held then 
			if s == e then 
				self._selection_dir = -1
			end

		--elseif control_held then find next space/char
			if (s > 0) and (self._selection_dir < 0) then -- forward select (increase selection)
				input_text:set_selection(s-1,e)
			elseif (e > 0) and (self._selection_dir > 0) then --backward select (decrease selection) 
				input_text:set_selection(s,e-1)
			end
		else --move caret
			if (s < e) then --cancel selection and move caret left
				input_text:set_selection(s,s)
			elseif (s > 0) then --else if no selection then keep caret left
				input_text:set_selection(s - 1, s - 1)
			end
		end
		self:reset_caret_blink_t()
	elseif k == Idstring("right") then
		local current_len = string.len(current_text)
		if ctrl_held then 
			local pattern
			local direction
			if self._selection_dir == -1 then 
				direction = s
			else
				direction = e
			end
			local current_char = string.sub(current_text,direction,direction)
			
			local space_index = string.find(current_char,"%s")
			if space_index then
				pattern = "^%s"
			else
				local alphanum_index = string.find(current_char,"%w") 
				if alphanum_index then
					--if currently at alphanumeric char(s), look for things that aren't that
					pattern = "^%w"
				else
					local punct_index = string.find(current_char,"%p")
					--same for punctuation
					if punct_index then
						pattern = "^%p"
					end
				end
--				string.find("asdkfjdlasdkjflakdfj  239847293847 (*#$&@$(*# &$( kjsdhfksjdh fK*(#@IHFIDS& *")
			end
			if pattern then
				local next_space_index_start,next_space_index_end = string.find(current_text,pattern,direction)
				if next_space_index_start then 
					if self._selection_dir == -1 then 
						input_text:set_selection(s,next_space_index_start)
					else
						input_text:set_selection(next_space_index_start,e)
					end
				end
			end
		end
		
		if shift_held then 
			if (s == e) then --if no selection then set direction right
				self._selection_dir = 1
			end
			if (e < current_len) and (self._selection_dir > 0) then --forward select (increase selection)
				input_text:set_selection(s,e + 1)
			elseif (e > s) and (self._selection_dir < 0) then --backward select (decrease selection)
				input_text:set_selection(s + 1,e)	
			end
		else
			if s < e then --cancel selection and keep caret right
				input_text:set_selection(e,e)
			elseif s < current_len then --move caret right
				input_text:set_selection(s + 1, s + 1)
			end
		end
		self:reset_caret_blink_t()
	elseif k == Idstring("down") then
		--newer history
		self:reset_caret_blink_t()
	elseif k == Idstring("up") then
		--older history
		self:reset_caret_blink_t()
	elseif k == Idstring("a") and ctrl_held then 
		local current_len = string.len(current_text)
		input_text:set_selection(0,current_len)	
--		input_text:replace_text("")
		self:reset_caret_blink_t()
	elseif k == Idstring("backspace") then --delete selection or text character behind caret
		local current_len = string.len(current_text)
		if s == e and s > 0 then
			input_text:set_selection(s - 1, e)
		end
		
		input_text:replace_text("")
		
		self:reset_caret_blink_t()
	elseif k == Idstring("delete") then --delete selection or text character after caret
		local current_len = string.len(current_text)
		if s == e and s < current_len then
			input_text:set_selection(s, e + 1)
		end

		input_text:replace_text("")
		self:reset_caret_blink_t()
	elseif k == Idstring("page up") then 
		--do scroll
	elseif k == Idstring("page down") then 
		--do scroll
	end
end

function ConsoleModDialog:GetHistory()
	
end

--todo allow selection of non input fields
function ConsoleModDialog:callback_key_press(o,k)
	self._key_held_ids = k
	self._key_held_t = self.INPUT_REPEAT_INTERVAL_INITIAL
	
	self:on_key_press(k,false)
end

function ConsoleModDialog:callback_key_release(o,k)
	if k == self._key_held_ids then
		self._key_held_ids = nil
		self._key_held_t = nil
	end
--	Log(o)
end

function ConsoleModDialog:key_shift_down()
	local k = Input:keyboard()

	return k:down(Idstring("left shift")) or k:down(Idstring("right shift")) or k:has_button(Idstring("shift")) and k:down(Idstring("shift"))
end

function ConsoleModDialog:key_ctrl_down()
	local k = Input:keyboard()
	return k:down(Idstring("left ctrl")) or k:down(Idstring("right ctrl")) or k:down(Idstring("ctrl"))
end

function ConsoleModDialog:key_alt_down()
	local k = Input:keyboard()
	return k:down(Idstring("left alt")) or k:down(Idstring("right alt")) or k:down(Idstring("alt"))
end

function ConsoleModDialog:enter_text(o,s)
	if self:key_ctrl_down() or self:key_alt_down() then 
		return 
	end
	self:reset_caret_blink_t()
--	Console:Print("enter text ", s)
	o:replace_text(s)
end

function ConsoleModDialog:update(t,dt)
	
	local input_text = self._input_text
	local s,e = input_text:selection()
	local char_index
	if self._selection_dir == -1 then
		char_index = s
	else
		char_index = e
	end
	
	if char_index then
		local caret_x,caret_y = input_text:character_rect(char_index)
		local caret = self._caret
--		local _,_,caret_w,caret_h = caret:text_rect()
		local font_size = self._data.font_size
		local caret_w = font_size / 4
		caret:set_world_position(caret_x - caret_w,caret_y)
		caret:set_alpha(math.sin(self._caret_blink_speed * (t - self._caret_blink_t)) > 0 and self._caret_blink_alpha_high or self._caret_blink_alpha_low)
	
		local p1x,p1y = input_text:character_rect(s)
		local p2x,p2y = input_text:character_rect(e)
		local selection_box = self._selection_box
		selection_box:set_world_position(p1x,p1y)
		selection_box:set_w(p2x - p1x)
		selection_box:set_h(font_size + (p2y - p1y))

--		self._history_text:set_text(string.format("%i / %i",self._input_text:selection()) .. "\n" .. string.format("%i / %i",selection_box:size()) .. "\n" .. string.format("%i / %i",selection_box:position()) .. "\n" .. string.format("%i / %i",self._mouse_x,self._mouse_y))
	end
	
	
	
	if self._is_holding_mouse_button then
		if self._mouse_x == self._old_x and self._mouse_y == self._old_y then
			self:callback_mouse_moved(self, self._mouse_x, self._mouse_y)
		end

		self._old_x = self._mouse_x
		self._old_y = self._mouse_y
	end
	if self._input_enabled then
		self:update_input(t, dt)
	end
	
--	local id,target = self:get_mouseover_target(self._mouse_x,self._mouse_y)
--	local s = tostring(id) .. string.format(" %i %i",self._mouse_x,self._mouse_y)
--self._history_text:set_text(string.format("%0.2f",self._key_held_t))
end

function ConsoleModDialog:update_input(t,dt)
	local dir, move_time = nil
	local move = self._controller:get_input_axis("menu_move")

	if self._controller:get_input_bool("menu_down") or move.y < -self.MOVE_AXIS_LIMIT then
		dir = 1
	elseif self._controller:get_input_bool("menu_up") or self.MOVE_AXIS_LIMIT < move.y then
		dir = -1
	end

	if dir then
		if self._move_button_dir == dir and self._move_button_time and t < self._move_button_time + self.MOVE_AXIS_DELAY then
			move_time = self._move_button_time or t
		else
--			self._panel_script:change_focus_button(dir)

			move_time = t
		end
	end

	self._move_button_dir = dir
	self._move_button_time = move_time
	
	if self._key_held_t then 
		self._key_held_t = self._key_held_t - dt
		if self._key_held_t <= 0 then
			self._key_held_t = self.INPUT_REPEAT_INTERVAL_CONTINUE
			
			self:update_key_down(t,dt,self._key_held_ids)
		end
	end
end

function ConsoleModDialog:update_key_down(t,dt,k)
--	self._key_held_ids
	self:on_key_press(k,true)
end

function ConsoleModDialog:set_input_enabled(enabled)
	local controller = self._controller
	if not self._input_enabled ~= not enabled then
		if enabled then
			controller:add_trigger("confirm", self._confirm_func)

			if managers.controller:get_default_wrapper_type() == "pc" or managers.controller:get_default_wrapper_type() == "steam" or managers.controller:get_default_wrapper_type() == "vr" then
				controller:add_trigger("toggle_menu", self._cancel_func)

				self._mouse_id = managers.mouse_pointer:get_id()
				self._removed_mouse = nil
				local data = {
					mouse_move = callback(self, self, "callback_mouse_moved"),
					mouse_press = callback(self, self, "callback_mouse_pressed"),
					mouse_release = callback(self, self, "callback_mouse_released"),
					mouse_click = callback(self, self, "callback_mouse_clicked"),
					id = self._mouse_id
				}
				self._fullscreen_ws:connect_keyboard(Input:keyboard())
				self._input_text:key_press(callback(self, self, "callback_key_press"))
				self._input_text:key_release(callback(self, self, "callback_key_release"))

				
				managers.mouse_pointer:use_mouse(data)
			else
				self._removed_mouse = nil

				controller:add_trigger("cancel", self._cancel_func)
				managers.mouse_pointer:disable()
			end
		else
			self._is_holding_mouse_button = false
			self._held_object = nil
			self._target_drag_x_start = nil
			self._target_drag_y_start = nil
			self._mouse_drag_x_start = nil
			self._mouse_drag_y_start = nil
		
			self._fullscreen_ws:disconnect_keyboard()
			self._panel:key_release(nil)
			self:release_scroll_bar()
			controller:remove_trigger("confirm", self._confirm_func)

			if managers.controller:get_default_wrapper_type() == "pc" or managers.controller:get_default_wrapper_type() == "steam" or managers.controller:get_default_wrapper_type() == "vr" then
				controller:remove_trigger("toggle_menu", self._cancel_func)
			else
				controller:remove_trigger("cancel", self._cancel_func)
			end

			self:remove_mouse()
		end

		self._input_enabled = enabled

		managers.controller:set_menu_mode_enabled(enabled)
	end
end

function ConsoleModDialog:show()
	if _G.setup and _G.setup:has_queued_exec() then
		return
	end
	managers.menu:post_event("prompt_enter") --snd
	self._panel:show()
	self._manager:event_dialog_shown(self)
	self:set_input_enabled(true)
	self._visible = true
	return true
end

function ConsoleModDialog:hide()
	self:set_input_enabled(false)
	self._key_held_ids = nil
	self._key_held_t = nil
	self._visible = false
	self._panel:hide()

	self._manager:event_dialog_hidden(self)
end

function ConsoleModDialog:close()
	self._manager:event_dialog_closed(self)
	self._panel:hide()
	self:_close_dialog_gui()
	self._visible = false
--	Dialog.close(self)
end

function ConsoleModDialog:force_close()
	self._manager:event_dialog_closed(self)
--	self:close()
	self._panel:hide()
	self._visible = false
	self:_close_dialog_gui()
--	Dialog.force_close(self)
end

function ConsoleModDialog:_hide_dialog_gui()
	self:set_input_enabled(false)
	self._parent_panel:set_visible(false)
--	self._panel_script:close()
	managers.viewport:remove_resolution_changed_func(self._resolution_changed_callback)
end

function ConsoleModDialog:remove_mouse()
	if not self._removed_mouse then
		self._removed_mouse = true

		if managers.controller:get_default_wrapper_type() == "pc" or managers.controller:get_default_wrapper_type() == "steam" or managers.controller:get_default_wrapper_type() == "vr" then
			managers.mouse_pointer:remove_mouse(self._mouse_id)
		else
			managers.mouse_pointer:enable()
		end

		self._mouse_id = nil
	end
end
function ConsoleModDialog:resolution_changed_callback()
	log("resolution changed")
end
function ConsoleModDialog:button_pressed_callback()
	log("confirm button presed")
	local input_text = self._input_text
	local current_text = input_text:text()
	local current_len = utf8.len(current_text)
	input_text:set_selection(0,current_len)
	input_text:replace_text("")
	if self._send_text_callback then
		self:_send_text_callback(current_text)
	end
--	self:remove_mouse()
--	self:button_pressed(self._panel_script:get_focus_button())
end
function ConsoleModDialog:dialog_cancel_callback()
	log("Cancel")
	self:hide()
	if #self._data.button_list == 1 then
		self:remove_mouse()
--		self:button_pressed(1)
	end

	for i, btn in ipairs(self._data.button_list) do
		if btn.cancel_button then
			self:remove_mouse()
--			self:button_pressed(i)

			return
		end
	end
end



--generic Dialog methods
function ConsoleModDialog:init_button_text_list()
	local button_list = self._data.button_list

	if button_list then
		for _, button in ipairs(button_list) do
			table.insert(self._button_text_list, button.text or "ERROR")
		end
	end

	if #self._button_text_list == 0 and not self._data.no_buttons then
		Application:error("[SystemMenuManager] Invalid dialog with no button texts. Adds an ok-button.")

		self._data.button_list = self._data.button_list or {}
		self._data.button_list[1] = self._data.button_list[1] or {}
		self._data.button_list[1].text = "ERROR: OK"

		table.insert(self._button_text_list, self._data.button_list[1].text)
	end
end
function ConsoleModDialog:title()
	return self._data.title
end
function ConsoleModDialog:text()
	return self._data.text
end
function ConsoleModDialog:focus_button()
	return self._data.focus_button
end
function ConsoleModDialog:button_pressed(button_index)
	cat_print("dialog_manager", "[SystemMenuManager] Button index pressed: " .. tostring(button_index))

	local button_list = self._data.button_list

	if button_list then
		local button = button_list[button_index]

		if not button.no_close then
			self:fade_out_close()
		end

		if button and button.callback_func then
			button.callback_func(button_index, button)
		end
	end

	local callback_func = self._data.callback_func

	if callback_func then
		callback_func(button_index, self._data)
	end
end
function ConsoleModDialog:button_text_list()
	return self._button_text_list
end

function ConsoleModDialog:to_string()
	local buttons = ""

	if self._data.button_list then
		for _, button in ipairs(self._data.button_list) do
			buttons = buttons .. "[" .. tostring(button.text) .. "]"
		end
	end

	return string.format("%s, Title: %s, Text: %s, Buttons: %s", tostring(BaseDialog.to_string(self)), tostring(self._data.title), tostring(self:_strip_to_string_text(self._data.text)), buttons)
end

function ConsoleModDialog:_strip_to_string_text(text)
	return string.gsub(tostring(text), "\n", "\\n")
end


--inherited GenericDialog methods 
function ConsoleModDialog:id()
	return self._data.id
end

function ConsoleModDialog:priority()
	return self._data.priority or 0
end

function ConsoleModDialog:get_platform_id()
	return managers.user:get_platform_id(self._data.user_index) or 0
end

function ConsoleModDialog:is_generic()
	return self._data.is_generic
end

function ConsoleModDialog:fade_in()
end

function ConsoleModDialog:fade_out_close()
	self:close()
end

function ConsoleModDialog:fade_out()
	self:close()
end

function ConsoleModDialog:_close_dialog_gui()
	self:set_input_enabled(false)
--	self._parent_panel:set_visible(false)
--	self._panel_script:close()
	managers.viewport:remove_resolution_changed_func(self._resolution_changed_callback)
end

function ConsoleModDialog:is_closing()
	return false
end

function ConsoleModDialog:_get_ws()
	return self._ws
end

function ConsoleModDialog:_get_controller()
	return self._controller
end

function ConsoleModDialog:blocks_exec()
	return true
end

