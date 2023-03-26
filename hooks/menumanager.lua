if not BeardLib then
	dofile(ModPath .. "Core.lua")
end

local orig_toggle_chatinput = MenuManager.toggle_chatinput
function MenuManager:toggle_chatinput(...)
	if Console._window_instance and Console._window_instance:is_focused() then
		return
	end
	return orig_toggle_chatinput(self,...)
end
