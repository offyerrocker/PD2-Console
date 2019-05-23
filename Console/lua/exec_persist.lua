if not (Console and Console._persist_scripts) then 
	return
else
	for keybind_id,keybind_data in pairs(Console._custom_keybinds) do 
		local k_result,k_fail
		local held = HoldTheKey:Keybind_Held(keybind_id)
		if keybind_data and type(keybind_data) == "table" then
			if held and ((not Console._keybind_cache[keybind_id]) or keybind_data.persist) then
				if keybind_data.clbk then 
					if type(keybind_data.clbk) == "function" then 
						k_result,k_fail = pcall(keybind_data.clbk)
						if not (k_result or keybind_data.persist) then 
							Console:Log("Keybind [" .. keybind_id .."]execution failed",{color = Color.red})
						end
					end
				end
			end
			Console._keybind_cache[keybind_id] = held
		end
	end
	for id, data in pairs(Console._persist_scripts) do 
		if data and type(data) == "table" then 
			local success_1,result_1,success_2,result_2
			if data.clbk then 
				success_1,result_1 = pcall(data.clbk) --execute given script
			end
			if success_1 then 
				if result_1 and data.clbk_success then 
					success_2,result_2 = pcall(data.clbk_success)
				end
			elseif data.clbk_fail then 
				success_2,result_2 = pcall(data.clbk_fail)				
			end
			local clbk_1_msg,clbk_2_msg
			
			if data.log_fail or data.log_all then 
				if not success_1 then 
					clbk_1_msg = "clbk failed with result " .. tostring(result_1)
				end
				if clbk_fail and not success_2 then 
					clbk_2_msg = "clbk_fail failed with result " .. tostring(result_2)
				end
			end
			if data.log_success or data.log_all then
				if success_1 then 
					clbk_1_msg = "clbk succeeded with result " .. tostring(result_1)
				end
				if clbk_success and success_2 then
					clbk_2_msg = "clbk_success succeeded with result " .. tostring(result_2)
				end
				
			end
			--[[	
			local clbk_1_msg = (success_1 and " successful with result [" .. tostring(result_1) .. "]") or (" unsuccessful.")
			local clbk_2_msg = (success_1 and clbk_success and " clbk_success ") or (not success_1 and data.clbk_fail and " clbk_fail ")
			if clbk_2_msg then 
				clbk_2_msg = clbk_2_msg .. " was " .. (success_2 and "successful " or "unsuccessful")
				clbk_2_msg = clbk_2_msg .. " with result [" .. tostring(result_2) .. "]"
			else
				clbk_2_msg = ""
			end	
			--]]
			if (clbk_1_msg or clbk_2_msg) then 
				Console:Log("Persist script [" .. id .. "]  was " .. (clbk_1_msg or "") .. (clbk_2_msg or ""))
			end
		else
			Console:Log("Invalid persist data")
			--invalid persist data
		end
	end
end