if Console then 
	local t = Application:time()
	local dt = t - Console._dt
	Console._dt = t
	
	Console:update(t,dt)
end