local orig_check_actions = PlayerMaskOff._update_check_actions
function PlayerMaskOff:_update_check_actions(t, dt,...)
	if Console._focus then 
		return
	else
		return orig_check_actions(self,t,dt,...)
	end
end