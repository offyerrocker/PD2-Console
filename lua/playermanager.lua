Hooks:Register("PlayerManager_on_internal_load")
Hooks:PostHook(PlayerManager,"_internal_load","console_on_event_playermanager_load",function(self)
	Hooks:Call("PlayerManager_on_internal_load")
end)