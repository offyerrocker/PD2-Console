--this file's only purpose is to stop input (player actions and movement) while the Console window is open
--would prefer to stop input at a higher level but i don't know if that's possible atm

--prevent player input; doesn't apply to BLT keybind input
local orig_input = PlayerStandard._get_input
function PlayerStandard:_get_input(t, dt, paused,...)
	if Console._focus then 
		return {}
	end
--	paused = OffyLib.console_focus or paused
	return orig_input(self,t,dt,paused,...)
end

local orig_move = PlayerStandard._determine_move_direction
function PlayerStandard:_determine_move_direction(...)
	if Console._focus then 
		return Vector3()
	end
	return orig_move(self,...)
end
