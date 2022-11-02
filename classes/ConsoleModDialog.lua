
--partly based on Dialog and child classes like DocumentDialog
ConsoleModDialog = ConsoleModDialog or class() --class(Dialog) --can't seem to get inheritance from this class to work

ConsoleModDialog.MOVE_AXIS_LIMIT = 0.4
ConsoleModDialog.MOVE_AXIS_DELAY = 0.4

ConsoleModDialog.INPUT_IGNORE_DELAY_INTERVAL = 0.05
ConsoleModDialog.INPUT_REPEAT_INTERVAL_INITIAL = 0.4
ConsoleModDialog.INPUT_REPEAT_INTERVAL_CONTINUE = 0.066
ConsoleModDialog.DEFAULT_FONT_NAME = tweak_data.hud.medium_font

function ConsoleModDialog:init(manager,data)
	
--	Dialog.init(self,manager,data)
	self._manager = manager
	self._data = data or {}
	self._font_asset_load_done = self._data.font_asset_load_done
	
	self._button_text_list = {}
	self:init_button_text_list()
	
	self._input_enabled = false

	--this functions as the main "enabled" flag
	self.is_active = false

	self._current_input_text_string = "" --this is only to be used for navigating the input history index
	self._input_history_index = 0

	
	self.inherited_settings = data.console_settings or {} --readonly! this is the Console settings table!
	
	self._current_window_color_ranges = {}
	self._current_range_data_index = 0
	
	self._output_log = self._data.output_log or {}
	self._input_log = self._data.input_log or {}
	
	--callbacks and input
	self._controller = self._data.controller or manager:_get_controller()
	self._confirm_func = callback(self, self, "button_pressed_callback") --automatic menu input for this is unreliable; use manual enter key detection (double input won't matter since the input text is wiped on send)
	self._cancel_func = callback(self, self, "dialog_cancel_callback")
	self._confirm_text_callback = self._data.confirm_text_callback 
	self._save_settings_callback = self._data.save_settings_callback
	
	--interface callback vars
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
	self._scrollbar_lock_enabled = self.inherited_settings.scrollbar_lock_enabled or false
	
	--text ui 
	self._selection_dir = 1 
	self._caret_blink_speed = 360
	self._caret_blink_t = 0
	self._caret_blink_alpha_high = 0.95
	self._caret_blink_alpha_low = 0
	
	self:create_gui()
end

function ConsoleModDialog:callback_on_delayed_asset_load(font_ids)
--	self._prompt:set_font(font_ids)
	self._input_text:set_font(font_ids)
	self._caret:set_font(font_ids)
	self._history_text:set_font(font_ids)
	self._header_label:set_font(font_ids)
	
	self._font_asset_load_done = true
end

function ConsoleModDialog:new_resize()
	
end

function ConsoleModDialog:create_gui()
	
	
--	do return self:new_create_gui() end
	

	local func_hex_to_color = Console.hex_number_to_color
	local settings = self.inherited_settings
	local buttons_atlas = "guis/textures/consolemod/buttons_atlas"
	local fullscreen_ws = managers.gui_data:create_fullscreen_workspace()
	self._fullscreen_ws = fullscreen_ws
	local parent_panel = fullscreen_ws:panel()
	self._parent_panel = parent_panel
	
	
	local text_font_name = settings.window_font_name
	if not self._font_asset_load_done then
		text_font_name = self.DEFAULT_FONT_NAME
	end
	
	local text_font_size = settings.window_font_size
	local text_normal_color = func_hex_to_color(settings.window_text_normal_color)
	local text_highlight_color = func_hex_to_color(settings.window_text_selected_color)
	local text_stale_color = func_hex_to_color(settings.window_text_stale_color)
	local selection_box_color = func_hex_to_color(settings.window_text_highlight_color)
	
	local header_label_margin_hor = 16 --used for placement
	local header_label_margin_ver = 4 --used for sizing, not placement- text is automatically vertically centered
	local header_label_valign = "center"
	local header_label_halign = "left"
	local header_label_font_name = text_font_name
	local header_label_font_size = text_font_size
	local header_label_color = text_normal_color
	local header_label_alpha = 1
	
	--prompt is no longer used
	local prompt_string = tostring(settings.window_prompt_string) or "> "
	local prompt_text_color = func_hex_to_color(settings.window_prompt_color)
	local prompt_text_alpha = settings.window_prompt_alpha
	local prompt_text_font_name = text_font_name
	local prompt_text_margin_hor = 1
	
	local caret_string = tostring(settings.window_caret_string) or "|"
	local caret_text_color = func_hex_to_color(settings.window_caret_color)
	local caret_text_alpha = settings.window_caret_alpha
	local caret_text_font_name = text_font_name
	
	local panel_x = settings.window_x
	local panel_y = settings.window_y
	local panel_w = settings.window_w
	local panel_h = settings.window_h
	local panel_alpha = settings.window_alpha
	
	local blur_alpha = settings.window_blur_alpha
	local bg_color = func_hex_to_color(settings.window_blur_alpha)
	local bg_alpha = settings.window_bg_alpha
	
	local panel_frame_color = func_hex_to_color(settings.window_frame_color)
	local panel_frame_alpha = settings.window_frame_alpha
		
		--aligned from panel right
	local close_button_margin_ver = 4
	local close_button_margin_hor = 4
	local close_button_w = 16
	local close_button_h = 16
	local button_normal_color = func_hex_to_color(settings.window_button_normal_color)
	local button_highlight_color = func_hex_to_color(settings.window_button_highlight_color)
	local close_button_color = button_normal_color
	
	local top_frame_w = panel_w
	local top_frame_h = 32 --aka body_margin_ver
	
	local bottom_frame_w = panel_w
	local bottom_frame_h = 32
	
	local history_margin_hor = 4
	local history_margin_ver = 4
	
	local body_margin_ver = top_frame_h --height of top frame
	local body_h = panel_h - (body_margin_ver * 2)
	
	local scrollbar_w = 16
	local scrollbar_h = body_h
	local scrollbar_button_size = scrollbar_w
	local scrollbar_handle_w = scrollbar_w
	local scrollbar_handle_h = 100
	
	local left_frame_w = 10 --left bar w
	local right_frame_w = left_frame_w -- + scrollbar_w
	
	local body_margin_hor = left_frame_w
	local body_w = panel_w - (body_margin_hor + right_frame_w)
	
	local input_text_margin_hor = 4
	local input_text_margin_ver = 1 --margin between text and input_box edges
	local input_text_font_size = text_font_size
	local input_text_alpha = 1
	local input_box_color = Color("444444")
	local input_box_alpha = 1
	
	local input_submit_button_w = 48 --! temp disabled
	local input_submit_button_margin_hor = 4
	local input_panel_w = body_w
	local input_panel_h = input_text_margin_ver + input_text_margin_ver + input_text_font_size
	local input_submit_button_h = input_panel_h
	local input_panel_margin_hor = left_frame_w
	local input_panel_margin_ver = (bottom_frame_h - input_panel_h) / 2 --! change this to have customizable above/below v margin
	local input_submit_button_color = Color("ff5500")
	local input_submit_button_alpha = 1
	
	local left_frame_h = body_h -- - (top_frame_h + bottom_frame_h)
	local right_frame_h = left_frame_h
	local left_frame_ver_margin = top_frame_h
	
	local resize_grip_w = 16
	local resize_grip_h = 16
	local resize_grip_color = Color.white
	
	local texture_blank = "guis/textures/test_blur_df"
	
	local panel = self._parent_panel:panel({
		name = "panel",
		x = panel_x,
		y = panel_y,
		w = panel_w,
		h = panel_h,
		alpha = panel_alpha,
		visible = false,
		layer = 999
	})
	self._panel = panel
	
	self._background_blur = panel:bitmap({
		name = "background_blur",
		texture = texture_blank,
		w = panel_w,
		h = panel_h,
		valign = "grow",
		render_template = "VertexColorTexturedBlur3D",
		color = Color.white,
		alpha = 1,
		layer = 0
	})
	self._background_rect = panel:rect({
		name = "background_rect",
		w = panel_w,
		h = panel_h,
		blend_mode = "normal",
		halign = "grow",
		valign = "grow",
		alpha = bg_alpha,
		color = bg_color,
		layer = 1
	})
		
	local scrollbar_panel = panel:panel({
		name = "scrollbar_panel",
		x = panel_w - (right_frame_w + scrollbar_w),
		y = top_frame_h,
		w = scrollbar_w,
		h = scrollbar_h,
		layer = 1009
	})
	self._scrollbar_panel = scrollbar_panel
		
	local scrollbar_button_lock = scrollbar_panel:bitmap({
		name = "scrollbar_button_lock",
		texture = "guis/textures/scroll_items",
		texture_rect = {
			0,16,
			16,16
		},
		x = 0,
		y = 0,
		w = scrollbar_button_size,
		h = scrollbar_button_size,
		alpha = scrollbar_lock_alpha,
		layer = 1000
	})
	self._scrollbar_button_lock = scrollbar_button_lock
	
	local scrollbar_button_top = scrollbar_panel:bitmap({
		name = "scrollbar_button_top",
		texture = "guis/textures/scroll_items",
		texture_rect = {
			0,0,
			15,15
		},
		w = scrollbar_button_size,
		h = scrollbar_button_size,
		x = 0,
		y = scrollbar_button_size,
		layer = 1000
	})
	self._scrollbar_button_top = scrollbar_button_top
	
	local scrollbar_button_up = scrollbar_panel:bitmap({
		name = "scrollbar_button_up",
		texture = "guis/textures/menu_arrows",
		texture_rect = {
			0,0,
			24,24
		},
		rotation = 90,
		w = scrollbar_button_size,
		h = scrollbar_button_size,
		x = 0,
		y = scrollbar_button_size * 2,
		layer = 1000
	})
	self._scrollbar_button_up = scrollbar_button_up
	
	local scrollbar_button_bottom = scrollbar_panel:bitmap({
		name = "scrollbar_button_bottom",
		texture = "guis/textures/scroll_items",
		texture_rect = {
			15,1,
			15,15
		},
		w = scrollbar_button_size,
		h = scrollbar_button_size,
		x = 0,
		y = scrollbar_h - scrollbar_button_size,
		layer = 1000
	})
	self._scrollbar_button_bottom = scrollbar_button_bottom
	
	local scrollbar_button_down = scrollbar_panel:bitmap({
		name = "scrollbar_button_down",
		texture = "guis/textures/menu_arrows",
		texture_rect = {
			0,0,
			24,24
		},
		rotation = 270,
		w = scrollbar_button_size,
		h = scrollbar_button_size,
		x = 0,
		y = scrollbar_h - (scrollbar_button_size * 2),
		layer = 1000
	})
	self._scrollbar_button_down = scrollbar_button_down
	
	local scrollbar_handle = scrollbar_panel:bitmap({
		name = "scrollbar_handle",
		texture = "guis/textures/scroll_items",
		texture_rect = {
			32,0,
			11,32
		},
		x = 0,
		y = scrollbar_button_size * 3,
		w = scrollbar_handle_w,
		h = scrollbar_handle_h,
		color = Color.white,
		alpha = 1,
		layer = 1000
	})
	self._scrollbar_handle = scrollbar_handle
	
	local top_frame_panel = panel:panel({
		name = "top_frame_panel",
		x = 0,
		y = 0,
		w = top_frame_w,
		h = top_frame_h,
		layer = 1000
	})
	local top_frame_bg = top_frame_panel:rect({
		name = "top_frame_bg",
		w = top_frame_w,
		h = top_frame_h,
		valign = "grow",
		halign = "grow",
		color = panel_frame_color,
		alpha = panel_frame_alpha,
		layer = 1001
	})
	local close_button = top_frame_panel:bitmap({
		name = "close_button",
		texture = buttons_atlas,
		texture_rect = {
			3 * 16, 1 * 16,
			16,16
		},
		x = top_frame_w - (close_button_w + close_button_margin_hor),
		y = close_button_margin_ver,
		w = close_button_w,
		h = close_button_h,
		color = close_button_color,
		alpha = 1,
		layer = 1002
	})
	self._close_button = close_button
	
	local header_label = top_frame_panel:text({
		name = "header_label",
		text = managers.localization:text("dcc_window_header_title"),
		font = text_font_name,
		font_size = text_font_size,
		color = text_normal_color,
		selection_color = text_highlight_color,
		align = "left",
		vertical = "center",
		x = header_label_margin_hor,
		y = 0,
		w = top_frame_w,
		h = top_frame_h,
		wrap = false,
		alpha = header_label_alpha,
		layer = 1009
	})
	self._header_label = header_label
	
	local bottom_frame_panel = panel:panel({
		name = "bottom_frame_panel",
		x = 0,
		y = panel_h - bottom_frame_h,
		w = bottom_frame_w,
		h = bottom_frame_h,
		layer = 1001
	})
	local bottom_frame_bg = bottom_frame_panel:rect({
		name = "bottom_frame_bg",
		w = bottom_frame_w,
		h = bottom_frame_h,
		valign = "grow",
		halign = "grow",
		color = panel_frame_color,
		alpha = panel_frame_alpha,
		layer = 9
	})
	local resize_grip = bottom_frame_panel:bitmap({
		name = "resize_grip",
		texture = buttons_atlas,
		texture_rect = {
			2 * 16, 1 * 16,
			16,16
		},
		x = bottom_frame_w - resize_grip_w,
		y = bottom_frame_h - resize_grip_h,
		w = resize_grip_w,
		h = resize_grip_h,
		color = resize_grip_color,
		alpha = 1,
		layer = 1000
	})
	self._resize_grip = resize_grip
	
	local left_frame_panel = panel:panel({
		name = "left_frame_panel",
		x = 0,
		y = left_frame_ver_margin,
		w = left_frame_w,
		h = left_frame_h,
		layer = 1001
	})
	local left_frame_bg = left_frame_panel:rect({
		name = "left_frame_bg",
		w = left_frame_w,
		h = left_frame_h,
		valign = "grow",
		halign = "grow",
		color = panel_frame_color,
		alpha = panel_frame_alpha,
		layer = 1000
	})
	
	local right_frame_panel = panel:panel({
		name = "right_frame_panel",
		x = panel_w - right_frame_w,
		y = left_frame_ver_margin,
		w = right_frame_w,
		h = right_frame_h,
		layer = 1001
	})
	local right_frame_bg = right_frame_panel:rect({
		name = "left_frame_bg",
		w = right_frame_w,
		h = right_frame_h,
		valign = "grow",
		halign = "grow",
		color = panel_frame_color,
		alpha = panel_frame_alpha,
		layer = 1000
	})
	
	local input_panel = panel:panel({
		name = "input_panel",
		x = left_frame_w,
		y = panel_h - (input_panel_h + input_panel_margin_ver),
		w = input_panel_w,
		h = input_panel_h,
		layer = 1003
	})
	self._input_panel = input_panel

	local input_box = input_panel:rect({
		name = "input_box",
		w = input_panel_w - (input_submit_button_w + (input_submit_button_margin_hor * 2)),
		h = input_panel_h,
		color = input_box_color,
		alpha = input_box_alpha,
		layer = 1010
	})
	self._input_box = input_box
	
	local input_text = input_panel:text({
		name = "input_text",
		text = "",
		font = text_font_name,
		font_size = text_font_size,
		color = text_normal_color,
		selection_color = text_highlight_color,
		align = "left",
		vertical = "center",
		x = input_text_margin_hor,
		y = 0,
		w = input_panel_w,
		h = input_panel_h,
		wrap = false,
		alpha = input_text_alpha,
		layer = 1111
	})
	self._input_text = input_text
	
	local input_submit_panel = input_panel:panel({
		name = "input_submit_panel",
		x = input_panel_w - input_submit_button_w,
		y = 0,
		w = input_submit_button_w,
		h = input_submit_button_h,
		layer = 1110
	})
	local input_submit_button = input_submit_panel:rect({
		name = "input_submit_button",
		w = input_submit_button_w,
		h = input_submit_button_h,
		color = input_submit_button_color,
		alpha = input_submit_button_alpha,
		layer = 1112
	})
	local input_submit_label = input_submit_panel:text({
		name = "input_submit_label",
		text = managers.localization:text("dcc_window_button_submit"),
		font = text_font_name,
		font_size = text_font_size,
		color = text_normal_color,
		selection_color = text_highlight_color,
		align = "center",
		vertical = "center",
		wrap = false,
		visible = true,
		alpha = 1,
		layer = 1113
	})
	
	local caret = input_panel:text({
		name = "caret",
		text = caret_string,
		font = caret_text_font_name,
		font_size = text_font_size,
		color = caret_text_color,
		x = 0,
		y = 0,
		alpha = caret_text_alpha,
		layer = 1112
	})
	self._caret = caret
	
	local selection_box = input_panel:rect({
		name = "selection_box",
		x = 0,
		y = 0,
		w = 0,
		h = 0,
		color = selection_box_color,
		alpha = 1,
		blend_mode = "normal",
		layer = 1110
	})
	self._selection_box = selection_box
	
	local body = panel:panel({
		name = "body",
		x = body_margin_hor,
		y = body_margin_ver,
		w = body_w,
		h = body_h,
		alpha = 1,
		layer = 1009
	})
	self._body = body
	
	self._prompt = body:text({
		name = "prompt",
		text = prompt_string,
		x = 0,
		y = 0,
--		monospace = true,
		font = text_font_name,
		font_size = text_font_size,
		align = "left",
		vertical = "bottom",
--		blend_mode = "add",
		color = prompt_text_color,
		alpha = prompt_text_alpha,
		layer = 1002,
	})
	
	local body_bg = body:rect({
		name = "body_bg",
		w = body_w,
		h = body_h,
		color = bg_color,
		alpha = bg_alpha,
		layer = 900
	}) 
	
	local history_text = body:text({
		name = "history_text",
		text = "",
		font = text_font_name,
		font_size = text_font_size,
		color = history_color,
		selection_color = text_highlight_color,
		x = history_margin_hor,
		y = history_margin_ver,
		w = body_w - (history_margin_hor * 2),
		h = body_h - (history_margin_ver * 2),
		align = "left",
		vertical = "bottom",
		wrap = true,
		alpha = 1,
		layer = 1111
	})
	self._history_text = history_text
	
	local min_window_width = 50
	local min_window_height = 50 + top_frame_h
	local max_window_hidden_hor_margin = 64 --no more than this many pixels of the window can be horizontally hidden (above or below the edge of the screen)
	local max_window_hidden_ver_margin = 0 --no more than this many pixels of the window can be vertically hidden (above or below the edge of the screen)
	self._ui_objects = {
		top_frame_bg = {
			object = top_frame_bg,
			mouseover_pointer = "hand", --arrow link hand grab
			mouseover_event_start_callback = nil,
			mouseover_event_stop_callback = nil,
			mouse_left_release_callback = nil,
			mouse_left_click_callback = function(o,x,y) --left click (on release)
				if self._save_settings_callback then 
					self._save_settings_callback()
				end
			end,
			mouse_right_click_callback = function(o,x,y) --right click (on release)
				--show context menu (click)
			end,
			mouse_left_press_callback = function(o,x,y) --left click (on initial press)
				self._mouse_drag_x_start = x
				self._mouse_drag_y_start = y
				self._held_object = o
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
				
				
				local bw,bh = o:size()
				local to_x = math.clamp( start_x + d_x, max_window_hidden_hor_margin - bw, parent_panel:w() - max_window_hidden_hor_margin )
				local to_y = math.clamp( start_y + d_y, max_window_hidden_ver_margin - bh, parent_panel:h() - (bh + max_window_hidden_ver_margin) )
				
				panel:set_position(to_x,to_y)
				self.inherited_settings.window_x = to_x
				self.inherited_settings.window_y = to_y
			end
		},
		input_submit_button = {
			object = input_submit_button,
			mouseover_pointer = "link",
			mouseover_event_start_callback = nil,
			mouseover_event_stop_callback = nil,
			mouse_left_release_callback = nil,
			mouse_left_click_callback = function(o,x,y) --left click (on release)
				self:confirm_text()
			end,
			mouse_right_click_callback = nil,
			mouse_left_press_callback = nil,
			mouse_right_press_callback = nil, --todo context menu?
			mouse_drag_event_callback = nil
		},
		resize_grip = {
			object = resize_grip,
			mouseover_pointer = "hand",
			mouseover_event_start_callback = nil,
			mouseover_event_stop_callback = nil,
			mouse_left_release_callback = nil,
			mouse_left_click_callback = function(o,x,y)
				if self._save_settings_callback then 
					self._save_settings_callback()
				end
			end,
			mouse_right_click_callback = function(o,x,y)
			end,
			mouse_left_press_callback = function(o,x,y)
				self._mouse_drag_x_start = x
				self._mouse_drag_y_start = y
				self._held_object = resize_grip
				self._target_drag_x_start = o:x()
				self._target_drag_y_start = o:y()
			end,
			mouse_right_press_callback = function(o,x,y)
			end,
			mouse_drag_event_callback = function(o,x,y)
				local px,py = panel:position()
				local msx = self._mouse_drag_x_start - px
				local msy = self._mouse_drag_y_start - py
				local tsx = self._target_drag_x_start
				local tsy = self._target_drag_y_start
				local d_x = msx - tsx
				local d_y = msy - tsy

				local to_w = math.max((x + d_x) - (px),min_window_width)
				local to_h = math.max((y + d_y) - (py),min_window_height)
				self:resize_panel(to_w,to_h)
				self.inherited_settings.window_w = to_w
				self.inherited_settings.window_h = to_h
			end
		},
		close_button = {
			object = self._close_button,
			mouseover_pointer = "link",
			mouseover_event_start_callback = function(o,x,y)
				o:set_color(button_highlight_color)
			end,
			mouseover_event_stop_callback = function(o,x,y)
				o:set_color(Color.red)
			end,
			mouse_left_release_callback = nil,
			mouse_left_click_callback = function(o,x,y) self:hide() end
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
			mouse_left_release_callback = nil,
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
			mouse_left_release_callback = nil,
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
			mouse_left_release_callback = nil,
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
			mouse_left_release_callback = nil,
			mouse_left_click_callback = callback(self,self,"callback_scrollbar_top_button_clicked")
		},
		scrollbar_button_lock = {
			object = scrollbar_button_lock,
			mouseover_pointer = "link",
			mouseover_event_start_callback = function(o,x,y)
				o:set_color(button_highlight_color)
			end,
			mouseover_event_stop_callback = function(o,x,y)
				o:set_color(Color.white)
			end,
			mouse_left_release_callback = nil,
			mouse_left_click_callback = callback(self,self,"callback_on_scrollbar_lock_button_clicked")
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
				local scrollbar_handle_h = scrollbar_handle:h()
				local y_min = scrollbar_button_up:bottom()
				local y_max = scrollbar_button_down:top() - scrollbar_handle_h
				local d_x = x - self._mouse_drag_x_start
				local d_y = y - self._mouse_drag_y_start
				
				local to_y = math.clamp(self._target_drag_y_start + d_y, y_min, y_max)
				local total = y_max - y_min
				--scroll event (d_y)
				--disable autoscroll while holding bar
				
				o:set_y(to_y)
				local ratio = (to_y - y_min) / (y_max - y_min)
				self:set_vscroll_ratio(ratio,true)
				self:set_vscroll_handle_by_position(to_y)
			end
		}
	}
	self._input_text:enter_text(callback(self,self,"enter_text"))
	self:generate_history(text_stale_color)
	self:resize_panel(panel_w,panel_h)
end

function ConsoleModDialog:resize_panel(to_w,to_h)
	
	
	
	
	
	do return self:new_resize() end
	
	local panel = self._panel
	panel:set_size(to_w,to_h)
	local panel_right = panel:right()
	local close_button_margin = 16
	local close_button_w = 16
	local body_margin_hor = 6
	local body_margin_ver = 6
	local top_bar_h = 16
	local text_font_size = self.inherited_settings.window_font_size
	local input_box_h = text_font_size * 1.5
	
	local resize_grip = self._resize_grip
	resize_grip:set_right(to_w)
	resize_grip:set_bottom(to_h)

--force reposition
--	self:set_scroll_amount(0) --force refresh scroll position
	self._body:set_size(to_w-(body_margin_hor * 2),to_h-(input_box_h + top_bar_h + (body_margin_ver * 2)))
	local b_w,b_h = self._body:size()
	--force update text objects
	self._input_text:set_size(b_w,b_h)
	self._input_text:set_text(self._input_text:text())
	self._input_box:set_size(b_w,input_box_h)
	self._input_box:set_position(body_margin_hor,b_h - text_font_size)
	self._prompt:set_size(b_w,b_h)
	self._prompt:set_text(self._prompt:text())
	self._body_bg:set_size(b_w,b_h)
	self._history_text:set_size(b_w,b_h - text_font_size)
	self._history_text:set_text(self._history_text:text())
	self._caret:set_size(b_w,b_h)
	self._caret:set_text(self._caret:text())
	self._top_bar:set_w(to_w)
--	self._top_grip:set_w(to_w - close_button_w)
	self._close_button:set_position(to_w - (close_button_w + close_button_margin))
	
	local vertical_margin = 24
	local scrollbar_button_h = 16
	local resize_grip_h = scrollbar_button_h
	--reposition individual scrollbar elements
	--recalculate scrollbar_handle position
	self._scrollbar_panel:set_h(to_h)
--	self._scrollbar_panel:set_x(b_w)
	self._scrollbar_panel:set_right(panel:w())
	self._scrollbar_lock_button:set_y(vertical_margin)
	self._scrollbar_button_top:set_y(self._scrollbar_lock_button:bottom())
	self._scrollbar_button_up:set_y(self._scrollbar_button_top:bottom())
	self._scrollbar_button_bottom:set_bottom(self._scrollbar_panel:h() - (vertical_margin + resize_grip_h))
	self._scrollbar_button_down:set_y(self._scrollbar_button_bottom:top() - scrollbar_button_h)
	--]]
end

function ConsoleModDialog:generate_history(color)
--	for k,v in pairs(self._history_log) do 
--	end
	local history_text = self._history_text
	local new_str = Console.table_concat(self._output_log,"\n")
	history_text:set_text(new_str)
	local new_length = self._current_range_data_index + utf8.len(new_str)
	table.insert(self._current_window_color_ranges,#self._current_window_color_ranges+1,{
		start = self._current_range_data_index,
		finish = new_length,
		color = color
	})
	local _,_,_,h = history_text:text_rect()
	history_text:set_h(h)
	history_text:set_range_color(self._current_range_data_index,new_length,color)
	self._current_range_data_index = new_length
end

function ConsoleModDialog:confirm_text()
--	log("confirm button presed")
	local input_text = self._input_text
	local current_text = input_text:text()
	local current_len = utf8.len(current_text)
	local settings = self.inherited_settings
	local color = settings.window_text_normal_color
	local prompt_string = settings.window_prompt_string
	input_text:set_selection(0,current_len)
	input_text:replace_text("")
	self:set_current_history_input_text("")
	self:add_to_history(prompt_string .. current_text,{
		start = 0,
		finish = current_len + utf8.len(prompt_string),
		color = Color(string.format("%06x",color))
	})
	
	self:_confirm_text(current_text)
end

function ConsoleModDialog:_confirm_text(s)
	local new_s,colors
	if self._confirm_text_callback then
		new_s,colors = self:_confirm_text_callback(s)
	end
	self:add_to_history(new_s,colors)
end

function ConsoleModDialog:add_to_history(s,colors)
	if s then
		local always_show_nil = true --todo
		if not always_show_nil then 
			return
		end
	end
	local _s = tostring(s)
	local history_text = self._history_text
	local current_text = history_text:text()
	local prev_lines = history_text:number_of_lines()
	history_text:set_text(current_text .. "\n" .. _s)
	local _,_,tw,th = history_text:text_rect()
	history_text:set_size(tw,th)
	
	--[[
	if self._scrollbar_lock_enabled then
		local current_lines = history_text:number_of_lines()
		local delta = current_lines - prev_lines
		self:set_scroll_amount(delta * self.inherited_settings.window_font_size)
	end
	--]]
	
	local offset = self._current_range_data_index
	if type(colors) == "table" then
		for i,range_data in ipairs(colors) do 
			range_data.start = range_data.start + offset
			range_data.finish = range_data.finish + offset
			table.insert(self._current_window_color_ranges,#self._current_window_color_ranges+1,range_data)
		end
	end
	offset = offset + 1 + utf8.len(_s)
	self._current_range_data_index = offset
	self:refresh_history_colors()
end

function ConsoleModDialog:refresh_history_colors() --not used
	local history_text = self._history_text
--		self._history_text:clear_range_color()
	for i,range_data in ipairs(self._current_window_color_ranges) do 
		history_text:set_range_color(range_data.start,range_data.finish,range_data.color)
	end
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
	self:set_vscroll_ratio(0)
end

function ConsoleModDialog:callback_on_scrollbar_bottom_button_clicked(o,x,y)
	self:set_vscroll_ratio(1)
end

function ConsoleModDialog:callback_on_scrollbar_up_button_clicked(o,x,y)
	local direction = self:is_scrollbar_direction_reversed() and 1 or -1
	self:perform_vscroll_amount(direction * self._body:h())
end

function ConsoleModDialog:callback_on_scrollbar_down_button_clicked(o,x,y)
	local direction = self:is_scrollbar_direction_reversed() and -1 or 1
	self:perform_vscroll_amount(direction * self._body:h())
end

function ConsoleModDialog:callback_on_scrollbar_lock_button_clicked(o,x,y)
	local scrollbar_lock_alpha_high = 1
	local scrollbar_lock_alpha_low = 0.5
	local state = not self:is_scrollbar_lock_enabled()
	if state then 
		o:set_alpha(scrollbar_lock_alpha_high)
	else
		o:set_alpha(scrollbar_lock_alpha_low)
	end
	self:set_scrollbar_lock_enabled(state)
end

function ConsoleModDialog:is_scrollbar_lock_enabled()
	return self.inherited_settings.window_scrollbar_lock_enabled
end

function ConsoleModDialog:set_scrollbar_lock_enabled(state)
	self.inherited_settings.window_scrollbar_lock_enabled = state
end

function ConsoleModDialog:is_scrollbar_direction_reversed()
--if false, the scrollbar at the top of the screen means that you are viewing the latest (most recent) logs
--if true, the scrollbar at the top of the screen means that you are viewing the earliest (least recent) logs

	return self.inherited_settings.window_scroll_direction_reversed
end

function ConsoleModDialog:is_scrollwheel_direction_reversed()
	--if true, mouse wheel up will move the scrollbar down (which moves text according to the setting is_scrollbar_direction_reversed() )
	--if false, mouse wheel down will move the scrollbar down 
	return self.inherited_settinngs.input_mousewheel_scroll_direction_reversed
end

function ConsoleModDialog:play_button_pressed_sound()
--	managers.menu:post_event()
end

function ConsoleModDialog:play_button_released_sound(success)
	if success then
--	managers.menu:post_event()
	else
--	managers.menu:post_event()
	end
end

function ConsoleModDialog:set_vscroll_ratio(ratio,skip_handle_position)
	
	local history_text = self._history_text
	
	local _,_,_,th = history_text:text_rect() --actual size
	local y_min = - math.abs(self._body:h() - th)
	local y_max = 0
	
	local total = y_min - y_max
	
	local d_y = total * ratio
	
	history_text:set_y(d_y)
	if not skip_handle_position then
		if self:is_scrollbar_direction_reversed() then
			ratio = 1 - ratio
		end
		self:set_vscroll_handle_by_ratio(ratio)
	end
end

function ConsoleModDialog:perform_vscroll_amount(d_y,skip_handle_position)
	local history_text = self._history_text
	local _,_,_,th = history_text:text_rect() --actual size
	local y_min = - math.abs(self._body:h() - th)
	local y_max = 0
	local to_y = math.clamp(history_text:y() + d_y,y_min,y_max)
	history_text:set_y(to_y)
	
	local ratio = (to_y - y_min) / (y_max - y_min)
	--[[
	if not skip_handle_position then
		if not self:is_scrollbar_direction_reversed() then
			ratio = 1 - ratio
		end
		self:set_vscroll_handle_by_ratio(ratio)
	end
	--]]
	self:set_vscroll_handle_by_ratio(ratio)
end


function ConsoleModDialog:set_vscroll_handle_by_position(position)
	local scrollbar_handle = self._scrollbar_handle
	local y_min = self._scrollbar_button_up:bottom()
	local y_max = self._scrollbar_button_down:top() - scrollbar_handle:h()
	self._scrollbar_handle:set_y(math.clamp(position,y_min,y_max))
end

function ConsoleModDialog:set_vscroll_handle_by_ratio(ratio)
	local scrollbar_handle = self._scrollbar_handle
	local top = self._scrollbar_button_up:y() + self._scrollbar_button_up:h()
	local bottom = self._scrollbar_button_down:y() - scrollbar_handle:h()
	local scrollbar_direction_reversed = self.inherited_settings.window_scroll_direction_reversed
	if scrollbar_direction_reversed then
		scrollbar_handle:set_y( bottom - ((bottom - top) * ratio) ) --top + ((min_y - max_y) * ratio))
	else
		scrollbar_handle:set_y( top + ((bottom - top) * ratio) )
	end
end


function ConsoleModDialog:set_vscroll_handle_height(ratio)
	local default_scrollbar_handle_height = 100
	local scrollbar_handle = self._scrollbar_handle
	scrollbar_handle:set_h(ratio * default_scrollbar_handle_height)
end

function ConsoleModDialog:set_vscroll_bar_height(ratio)
	local default_scrollbar_handle_height = 100
	local scrollbar_handle = self._scrollbar_handle
	scrollbar_handle:set_h(ratio * default_scrollbar_handle_height)
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
--	log("pressed  " .. tostring(x) .. " " .. tostring(y))
	
	if button == Idstring("0") then
		self._is_holding_mouse_button = true
		local id,mouseover_target = self:get_mouseover_target(x,y)
		
		--drag start (can be overridden by object-specific callbacks)
		self._mouse_drag_x_start = x
		self._mouse_drag_y_start = y
		self._target_drag_x_start = x
		self._target_drag_y_start = y
		self._held_object = mouseover_target
		
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
		local direction = self:is_scrollbar_direction_reversed() and -1 or 1
		self:perform_vscroll_amount(direction * self.inherited_settings.window_font_size)
	elseif button == Idstring("mouse wheel down") then 
		local direction = self:is_scrollbar_direction_reversed() and 1 or -1
		self:perform_vscroll_amount(direction * self.inherited_settings.window_font_size)
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
						log("leftclick  " .. tostring(x) .. " " .. tostring(y))
						ui_object_data.mouse_left_click_callback(mouseover_target,x,y)
					end
				end
				
				if ui_object_data.mouse_left_release_callback then
					ui_object_data.mouse_left_release_callback(mouseover_target,x,y)
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

function ConsoleModDialog:callback_mouse_clicked(o,button,x,y) --don't use this
--	log("Mouse clicked")
	--[[
		--this callback is called whenever the mouse is released after clicking.
		--but it isn't capable of checking whether the mouseover object is the same one from when the mouse was pressed.
		--and by definition a mouse must always first press before releasing. that is how clicks work.
		--also it's executed after release instead of before.
		--so it's completely worthless to me. 
		
	if button == Idstring("0") then 
		local id,mouseover_target = self:get_mouseover_target(x,y)
		if id then
			local ui_object_data = self._ui_objects[id]
			if ui_object_data.mouse_left_click_callback then
				ui_object_data.mouse_left_click_callback(mouseover_target,x,y)
			end
		end	
	end
	--]]
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
		self:set_current_history_input_text(current_text)
		self:confirm_text()
	elseif k == Idstring("`") and not shift_held then 
	elseif k == Idstring("v") and ctrl_held then
		local clipboard = Application:get_clipboard()
		if clipboard then
			input_text:replace_text(tostring(clipboard))
		end
		self:reset_caret_blink_t()
		self:set_current_history_input_text(current_text)
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
		self._selection_dir = -1
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
		self._selection_dir = 1
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
		local num_input_log = #self._input_log
		if num_input_log > 0 then
			local new_text
			if self._input_history_index == 0 then 
				self:set_current_history_input_text(current_text)
			end
			
			local history_index = (1 + self._input_history_index) % num_input_log
			if history_index == 0 then 
				new_text = self._current_input_text_string
			else
				input_text:set_alpha(0.5)
				new_text = self._input_log[history_index].input
			end
			self._input_history_index = history_index
			if new_text then
				input_text:set_text(new_text)
				local new_len = string.len(new_text)
				input_text:set_selection(new_len,new_len)
			end
		end
		
		self:reset_caret_blink_t()
	elseif k == Idstring("up") then
		--older history
		
		local num_input_log = #self._input_log
		if num_input_log > 0 then
			local new_text
			if self._input_history_index == 0 then 
				self:set_current_history_input_text(current_text)
			end
			
			local history_index = (-1 + self._input_history_index) % num_input_log
			if history_index == 0 then 
				new_text = self._current_input_text_string
			else
				input_text:set_alpha(0.5)
				new_text = self._input_log[history_index].input
			end
			self._input_history_index = history_index
			if new_text then
				input_text:set_text(new_text)
				local new_len = string.len(new_text)
				input_text:set_selection(new_len,new_len)
			end
		end
		
		self:reset_caret_blink_t()
	elseif k == Idstring("a") and ctrl_held then 
		local current_len = string.len(current_text)
		input_text:set_selection(0,current_len)	
--		input_text:replace_text("")
		self:reset_caret_blink_t()
	elseif k == Idstring("backspace") then --delete selection or text character behind caret
		self:set_current_history_input_text(current_text)
		local current_len = string.len(current_text)
		if s == e and s > 0 then
			input_text:set_selection(s - 1, e)
		end
		input_text:replace_text("")
		
		self:reset_caret_blink_t()
	elseif k == Idstring("delete") then --delete selection or text character after caret
		self:set_current_history_input_text(current_text)
		
		if not shift_held then
			local current_len = string.len(current_text)
			if s == e and s < current_len then
				input_text:set_selection(s, e + 1)
			end
		end
		--input_text:set_selection(s,s)
		input_text:replace_text("")
		self:reset_caret_blink_t()
	elseif k == Idstring("page up") then 
		--do scroll
	elseif k == Idstring("page down") then 
		--do scroll
	end
end

function ConsoleModDialog:set_current_history_input_text(text)
	self._input_text:set_alpha(1)
	self._input_history_index = 0
	self._current_input_text_string = text
end

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
	self:set_current_history_input_text(o:text())
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
		local caret = self._caret
		local text_font_size = self.inherited_settings.window_font_size
		local caret_w = text_font_size / 4
		local caret_x,caret_y = input_text:character_rect(char_index)
		if input_text:text() == "" then
--			local prompt = self._prompt
--			local prompt_text = prompt:text()
--			local prompt_len = utf8.len(prompt_text)
--			caret_x,caret_y = prompt:character_rect(prompt_len)
			caret_x = self._input_box:x()
			--self._input_box:y()
			caret_y = self._prompt:y()
		else
	--		local _,_,caret_w,caret_h = caret:text_rect()
		end
		caret:set_world_position(caret_x - caret_w,caret_y)
		caret:set_alpha(math.sin(self._caret_blink_speed * (t - self._caret_blink_t)) > 0 and self._caret_blink_alpha_high or self._caret_blink_alpha_low)
		
		local p1x,p1y,_,_ = input_text:character_rect(s)
		local p2x,p2y,_,_ = input_text:character_rect(e)
		local selection_box = self._selection_box
		selection_box:set_world_position(p1x,p1y)
		selection_box:set_w(p2x - p1x)
		--[[
		local line_breaks = input_text:line_breaks()
		local num_line_breaks = #line_breaks
		if num_line_breaks > 1 then
			p1y = math.min(p1y,p2y)
			p2y = math.max(p2y,p3y)
			local _,p3y,_,_ = input_text:character_rect(line_breaks[num_line_breaks])
		end
		--]]
		selection_box:set_h((p2y - p1y) + (input_text:number_of_lines() * text_font_size) )

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
	elseif self._input_delay_timer then
		if self._input_delay_timer <= 0 then
			self._input_delay_timer = nil
			self:set_input_enabled(true)
		else
			self._input_delay_timer = self._input_delay_timer - dt
		end
	end
	
	local s = ""
--	local id,target = self:get_mouseover_target(self._mouse_x,self._mouse_y)
--	local s = tostring(id) .. string.format(" %i %i",self._mouse_x,self._mouse_y)
	s = s .. "\n" .. string.format("pos %i %i",self._history_text:position())
	s = s .. "\n" .. string.format("sze %i %i",self._history_text:size())
--	s = s .. "\n" .. string.format("%i %i",self._mouse_drag_x_start or -1,self._mouse_drag_y_start or -1)
--	s = s .. "\n" .. string.format("%i %i",self._target_drag_x_start or -1,self._target_drag_y_start or -1)
	self._prompt:set_text(s)
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

	self:update_key_down(t,dt,self._key_held_ids)
end

function ConsoleModDialog:update_key_down(t,dt,k)	
	if self._key_held_t then 
		self._key_held_t = self._key_held_t - dt
		if self._key_held_t <= 0 then
			self._key_held_t = self.INPUT_REPEAT_INTERVAL_CONTINUE
			
			self:on_key_press(k,true)
		end
	end
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
					mouse_click = callback(self, self, "callback_mouse_clicked"), --don't use this
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
	self._input_delay_timer = self.INPUT_IGNORE_DELAY_INTERVAL
	managers.menu:post_event("prompt_enter") --snd
	self._panel:show()
	self._manager:event_dialog_shown(self)
--	self:set_input_enabled(true)
	self.is_active = true
	return true
end

function ConsoleModDialog:hide()
	self:set_input_enabled(false)
	self._key_held_ids = nil
	self._key_held_t = nil
	self.is_active = false
	self:_hide_dialog_gui()
	managers.menu:post_event("menu_exit")
	self._manager:event_dialog_hidden(self)
end

function ConsoleModDialog:close()
	self._manager:event_dialog_closed(self)
	self:hide()
	self:_close_dialog_gui()
	self.is_active = false
--	Dialog.close(self)
end

function ConsoleModDialog:force_close()
	self._manager:event_dialog_closed(self)
--	self:close()
	self._panel:hide()
	self.is_active = false
	self:_close_dialog_gui()
--	Dialog.force_close(self)
end

function ConsoleModDialog:_hide_dialog_gui()
	self._panel:hide()
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
--	log("resolution changed")
--	self:resize_panel(self.inherited_settings.window_w,self.inherited_settings.window_h)
end
function ConsoleModDialog:button_pressed_callback()
	--self:confirm_text()
--	self:remove_mouse()
--	self:button_pressed(self._panel_script:get_focus_button())
end
function ConsoleModDialog:dialog_cancel_callback() --not really used?
--	log("Cancel")
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

--inherited Dialog methods
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


function ConsoleModDialog:release_scroll_bar()
	
end

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

