--!strict
-- Daily and weekly quests. Each player gets Config.Quests.Count of each, picked from the pools
-- in Config.Quests by a seed of their UserId and the day / week (so rejoining shows the same
-- ones), reset at 00:00 UTC (weekly: Monday). Progress comes from Progression.record events; a
-- finished quest is claimed from the Quests tab (ClaimQuest remote) for its coins and XP.
-- Stored in the profile: Quests = { Day, Daily = { {Id, Progress, Claimed} }, Week, Weekly }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DayClock = require(Shared.DayClock)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)

local Quests = {}

local POOLS = { Daily = "Daily", Weekly = "Weekly" }

local function definition(kind: string, id: string): { [string]: any }?
	for _, quest in Config.Quests[kind] do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

-- Picks `count` different quests from a pool with a seeded random.
local function pick(pool: { { [string]: any } }, seed: number): { { [string]: any } }
	local rng = Random.new(seed)
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	local chosen = {}
	for _ = 1, math.min(Config.Quests.Count, #pool) do
		local index = table.remove(indices, rng:NextInteger(1, #indices)) :: number
		table.insert(chosen, { Id = pool[index].Id, Progress = 0, Claimed = false })
	end
	return chosen
end

-- Gives the player today's and this week's quests if theirs are out of date.
local function refresh(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local day, week = DayClock.day(), DayClock.week()
	if profile.Quests.Day == day and profile.Quests.Week == week then
		return
	end
	PlayerData.update(player, function(p)
		if p.Quests.Day ~= day then
			p.Quests.Day = day
			p.Quests.Daily = pick(Config.Quests.Daily, player.UserId * 31 + day)
		end
		if p.Quests.Week ~= week then
			p.Quests.Week = week
			p.Quests.Weekly = pick(Config.Quests.Weekly, player.UserId * 17 + week * 101)
		end
	end)
end

local function onRecord(player: Player, event: string, amount: number)
	refresh(player)
	local finished = {}
	PlayerData.update(player, function(p)
		for kind in POOLS do
			for _, quest in p.Quests[kind] do
				local def = definition(kind, quest.Id)
				if def and def.Event == event and quest.Progress < def.Goal then
					quest.Progress = math.min(def.Goal, quest.Progress + amount)
					if quest.Progress >= def.Goal then
						table.insert(finished, def.Text)
					end
				end
			end
		end
	end)
	for _, text in finished do
		Remotes.get("Notify"):FireClient(player, `Quest done: {text}! Claim it in Quests`)
	end
end

local function claim(player: Player, kind: any, slot: any)
	if not POOLS[kind] or type(slot) ~= "number" then
		return
	end
	refresh(player)
	local profile = PlayerData.get(player)
	local quest = profile and profile.Quests[kind][slot]
	local def = quest and definition(kind, quest.Id)
	if not quest or not def or quest.Claimed or quest.Progress < def.Goal then
		return
	end
	PlayerData.update(player, function(p)
		p.Quests[kind][slot].Claimed = true
	end)
	Progression.grant(player, { Coins = def.Coins, XP = def.XP }, "Quest complete!")
end

-- Dev panel: finishes all of the player's quests (to test claiming).
function Quests.completeAll(player: Player)
	refresh(player)
	PlayerData.update(player, function(p)
		for kind in POOLS do
			for _, quest in p.Quests[kind] do
				local def = definition(kind, quest.Id)
				if def then
					quest.Progress = def.Goal
				end
			end
		end
	end)
end

function Quests.start()
	Progression.onRecord(onRecord)
	PlayerData.onLoaded(function(player)
		refresh(player)
	end)
	Remotes.get("ClaimQuest").OnServerEvent:Connect(claim)
	-- New day or week while playing (or the dev calendar moved): hand out new quests.
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

return Quests
