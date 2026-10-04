--!strict
-- Achievements: long-term goals (Config.Achievements) like "Win 100 games". Checked whenever a
-- profile changes; reaching one marks it done (once, saved in the profile), pays its reward
-- (coins and/or exclusive cosmetics, through Progression.grant), and awards its Roblox badge if
-- it has a BadgeId.
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)

local Achievements = {}

local function value(profile: PlayerData.Profile, stat: string): number
	if stat == "Level" then
		return profile.Level
	elseif stat == "Streak" then
		return profile.Streak.Count
	end
	return profile.Stats[stat] or 0
end

local function check(player: Player)
	local reached = {}
	-- Decide and mark inside one update, so two checks at once can't both pay out.
	PlayerData.update(player, function(profile)
		for _, achievement in Config.Achievements do
			if
				not profile.Achievements[achievement.Id]
				and value(profile, achievement.Stat) >= achievement.Goal
			then
				profile.Achievements[achievement.Id] = true
				table.insert(reached, achievement)
			end
		end
	end)
	for _, achievement in reached do
		Progression.grant(
			player,
			{ Coins = achievement.Coins, Items = achievement.Items },
			`Achievement: {achievement.Text}!`
		)
		if achievement.BadgeId then
			task.spawn(pcall, function()
				BadgeService:AwardBadge(player.UserId, achievement.BadgeId)
			end)
		end
	end
end

function Achievements.start()
	PlayerData.onLoaded(function(player)
		check(player)
	end)
	PlayerData.onChanged(function(player, profile)
		-- Only look further when something might be newly reached (cheap test first).
		for _, achievement in Config.Achievements do
			if
				not profile.Achievements[achievement.Id]
				and value(profile, achievement.Stat) >= achievement.Goal
			then
				check(player)
				return
			end
		end
	end)
end

return Achievements
