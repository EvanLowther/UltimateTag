--!strict
-- The daily login streak. Once per UTC day (shared/DayClock) a player can claim a reward
-- (ClaimStreak remote). Claiming on the day after their last claim grows the streak; missing a
-- day starts it over at 1. Rewards cycle every 7 days (Config.Streak.Rewards; day 7 is the big
-- one), and long streaks unlock one-time extras (Config.Streak.Milestones).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DayClock = require(Shared.DayClock)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)

local DailyStreak = {}

-- The reward for streak day `count` (1, 2, 3...), cycling through the 7-day list.
function DailyStreak.rewardFor(count: number): { [string]: any }
	local rewards = Config.Streak.Rewards
	return rewards[((count - 1) % #rewards) + 1]
end

local function claim(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local today = DayClock.day()
	local streak = profile.Streak
	if streak.LastDay == today then
		return -- already claimed today
	end
	local count = if streak.LastDay == today - 1 then streak.Count + 1 else 1
	PlayerData.update(player, function(p)
		p.Streak.Count = count
		p.Streak.LastDay = today
	end)
	local reward = table.clone(DailyStreak.rewardFor(count))
	local milestone = Config.Streak.Milestones[count]
	if milestone and milestone.Items then
		reward.Items = milestone.Items
	end
	Progression.grant(player, reward, `Day {count} streak!`)
	Progression.record(player, "StreakDay")
end

function DailyStreak.start()
	Remotes.get("ClaimStreak").OnServerEvent:Connect(claim)
end

return DailyStreak
