if Console then 
	local t = Application:time()
	local dt = t - Console._dt
	Console._dt = t
	if Console.update then
		Console:update(t,dt)
	end
end