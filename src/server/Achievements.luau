--!strict
-- Achievements: long-term goals (Config.Achievements) like "Win 100 games". Progress is just
-- the player's stats, so it tracks itself; reaching a goal makes the achievement claimable
-- (a Notify message, and a badge on the Quests button), and the player claims it in the Quests
-- window (ClaimAchievement remote) for its reward (coins and/or exclusive cosmetics, through
-- Progression.grant) and its Roblox badge, if it has a BadgeId. Claimed ones are saved in the
-- profile (Achievements[id] = true).
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)

local Achievements = {}

local byId: { [string]: { [string]: any } } = {}
for _, achievement in Config.Achievements do
	byId[achievement.Id] = achievement
end

-- Achievements we've already told this player are ready (this session).
local told: { [Player]: { [string]: boolean } } = {}

-- A stat's current value for an achievement ("Level", "Streak", or a profile stat).
function Achievements.value(profile: PlayerData.Profile, stat: string): number
	if stat == "Level" then
		return profile.Level
	elseif stat == "Streak" then
		return profile.Streak.Count
	end
	return profile.Stats[stat] or 0
end

local function ready(profile: PlayerData.Profile, achievement: { [string]: any }): boolean
	return not profile.Achievements[achievement.Id]
		and Achievements.value(profile, achievement.Stat) >= achievement.Goal
end

-- Tells the player about achievements that just became claimable. `quiet`: just remember them
-- (on joining, the badge on the Quests button is enough).
local function announce(player: Player, profile: PlayerData.Profile, quiet: boolean)
	local seen = told[player]
	if not seen then
		seen = {}
		told[player] = seen
	end
	for _, achievement in Config.Achievements do
		if not seen[achievement.Id] and ready(profile, achievement) then
			seen[achievement.Id] = true
			if not quiet then
				Remotes.get("Notify")
					:FireClient(player, `Achievement ready: {achievement.Text}! Claim it in Quests`)
			end
		end
	end
end

local function claim(player: Player, id: any)
	local achievement = if type(id) == "string" then byId[id] else nil
	if not achievement then
		return
	end
	local granted = false
	-- Decide and mark inside one update, so two claims at once can't both pay out.
	PlayerData.update(player, function(profile)
		if ready(profile, achievement) then
			profile.Achievements[achievement.Id] = true
			granted = true
		end
	end)
	if not granted then
		return
	end
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

function Achievements.start()
	PlayerData.onLoaded(function(player, profile)
		announce(player, profile, true)
	end)
	PlayerData.onChanged(function(player, profile)
		announce(player, profile, false)
	end)
	Remotes.get("ClaimAchievement").OnServerEvent:Connect(claim)
	Players.PlayerRemoving:Connect(function(player)
		told[player] = nil
	end)
end

return Achievements
