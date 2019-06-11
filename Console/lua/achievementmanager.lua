local orig_award = AchievementManager.award
function AchievementManager:award(...)
	if not Console:AchievementsDisabled() then 
		return orig_award(self,...)
	end
end

local orig_progress = AchievementManager.award_progress
function AchievementManager:award_progress(...)
	if not Console:AchievementsDisabled() then 
		return orig_progress(self,...)
	end
end