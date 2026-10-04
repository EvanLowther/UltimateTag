--!strict
-- The one place progress is recorded. The game calls Progression.record(player, event) when
-- something happens (a game played, a round survived, a tag, a win, a minute of play, a move
-- during a round); this counts it in the player's stats, pays coins and XP
-- (Config.Progression.Events, plus bonuses), levels them up, and tells listeners (quests,
-- achievements) through Progression.onRecord.
--   Progression.grant(player, rewards, reason) pays out a reward bundle from anywhere (quests,
--   the login streak, achievements, the wheel): { Coins, XP, Crates, Items = { ids } }.
-- Earned things pop up on the player's screen through the Reward remote (client/Menu).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local DayClock = require(Shared.DayClock)
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local Participants = require(script.Parent.Participants)
local PlayerData = require(script.Parent.PlayerData)

local Progression = {}

export type Rewards = { Coins: number?, XP: number?, Crates: number?, Items: { string }? }

local MOVES = { WallRun = true, Slide = true, Vault = true, Climb = true }

local recordListeners: { (Player, string, number) -> () } = {}
local tagsThisRound: { [Player]: number } = {}
local lastMove: { [Player]: { [string]: number } } = {}
local friendInServer: { [Player]: boolean } = {}

local function popup(player: Player, payload: { [string]: any })
	Remotes.get("Reward"):FireClient(player, payload)
end

-- XP needed to go from `level` to the next.
function Progression.xpForLevel(level: number): number
	local settings = Config.Progression
	return settings.LevelBase + settings.LevelStep * (level - 1)
end

-- Adds coins and XP to a profile (inside a PlayerData.update), levelling up as far as the XP
-- goes. Returns the levels reached.
local function addCoinsAndXP(profile: PlayerData.Profile, coins: number, xp: number): { number }
	local settings = Config.Progression
	profile.Coins += coins
	profile.XP += xp
	local reached = {}
	while profile.XP >= Progression.xpForLevel(profile.Level) do
		profile.XP -= Progression.xpForLevel(profile.Level)
		profile.Level += 1
		table.insert(reached, profile.Level)
		profile.Coins += settings.LevelCoins + settings.LevelCoinsStep * profile.Level
		if profile.Level % settings.CrateEvery == 0 then
			profile.Crates += 1
		end
		local extra = settings.LevelRewards[profile.Level]
		if extra and extra.Items then
			for _, id in extra.Items do
				if Catalog.get(id) then
					profile.Owned[id] = true
				end
			end
		end
	end
	return reached
end

-- Shows each level reached (and what came with it).
local function announceLevels(player: Player, reached: { number })
	local settings = Config.Progression
	for _, level in reached do
		local items = {}
		local extra = settings.LevelRewards[level]
		if extra and extra.Items then
			items = extra.Items
		end
		popup(player, {
			Kind = "LevelUp",
			Level = level,
			Coins = settings.LevelCoins + settings.LevelCoinsStep * level,
			Crates = if level % settings.CrateEvery == 0 then 1 else 0,
			Items = items,
		})
	end
end

-- Pays a reward bundle: { Coins, XP, Crates, Items }. `reason` labels the popup.
function Progression.grant(player: Player, rewards: Rewards, reason: string?)
	local reached = {}
	local newItems = {}
	PlayerData.update(player, function(profile)
		for _, id in rewards.Items or {} do
			if Catalog.get(id) and not profile.Owned[id] then
				profile.Owned[id] = true
				table.insert(newItems, id)
			end
		end
		profile.Crates += rewards.Crates or 0
		reached = addCoinsAndXP(profile, rewards.Coins or 0, rewards.XP or 0)
	end)
	popup(player, {
		Kind = "Grant",
		Reason = reason,
		Coins = rewards.Coins or 0,
		XP = rewards.XP or 0,
		Crates = rewards.Crates or 0,
		Items = newItems,
	})
	announceLevels(player, reached)
end

-- Is a friend of this player in the server? (Checked when players join; friends get bonus XP.)
local function refreshFriends()
	local players = Players:GetPlayers()
	for _, player in players do
		local found = false
		for _, other in players do
			if other ~= player then
				local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and isFriend then
					found = true
					break
				end
			end
		end
		friendInServer[player] = found
	end
end

-- Records something that happened. Movement events only count while the player is alive in a
-- live round; tag rewards are capped per round.
function Progression.record(player: Player, event: string, amount: number?)
	local count = amount or 1
	local settings = Config.Progression
	local def = settings.Events[event]
	local profile = PlayerData.get(player)
	if not def or not profile then
		return
	end
	local phase = GameState.getPhase()
	if MOVES[event] or event == "Tag" then
		if phase ~= "Playing" or not Participants.isAlive(player) then
			return
		end
	end

	local coins = (def.Coins or 0) * count
	local xp = (def.XP or 0) * count
	local label = event
	if event == "Tag" then
		local done = tagsThisRound[player] or 0
		tagsThisRound[player] = done + count
		if done >= def.PerRound then
			coins, xp = 0, 0
		end
	end

	local reached = {}
	PlayerData.update(player, function(p)
		if def.Stat then
			p.Stats[def.Stat] += count
		end
		if event == "Win" then
			local today = DayClock.day()
			if p.FirstWinDay ~= today then
				p.FirstWinDay = today
				coins *= settings.FirstWinMultiplier
				label = "First win of the day"
			end
			p.Stats.WinStreak += 1
			p.Stats.BestWinStreak = math.max(p.Stats.BestWinStreak, p.Stats.WinStreak)
			local steps = math.min(p.Stats.WinStreak - 1, settings.StreakBonusCap)
			coins += settings.StreakBonus * steps
		elseif event == "GameLost" then
			p.Stats.WinStreak = 0
		end
		if friendInServer[player] then
			xp = math.floor(xp * (1 + settings.FriendXPBonus) + 0.5)
		end
		reached = addCoinsAndXP(p, coins, xp)
	end)
	if coins > 0 or xp > 0 then
		popup(player, { Kind = "Earned", Reason = label, Coins = coins, XP = xp })
	end
	announceLevels(player, reached)
	for _, listener in recordListeners do
		task.spawn(listener, player, event, count)
	end
end

-- Calls `listener(player, event, amount)` after every record (quests, achievements).
function Progression.onRecord(listener: (Player, string, number) -> ())
	table.insert(recordListeners, listener)
end

-- A new round: the per-round tag cap starts over.
function Progression.newRound()
	table.clear(tagsThisRound)
end

function Progression.start()
	-- Moves reported by the client: only real move names, throttled per kind.
	Remotes.get("MoveDone").OnServerEvent:Connect(function(player, move)
		if type(move) ~= "string" or not MOVES[move] then
			return
		end
		local times = lastMove[player] or {}
		lastMove[player] = times
		local now = os.clock()
		if now - (times[move] or -math.huge) < Config.Progression.MoveCooldown then
			return
		end
		times[move] = now
		Progression.record(player, move)
	end)

	Players.PlayerAdded:Connect(function()
		task.wait(2)
		refreshFriends()
	end)
	Players.PlayerRemoving:Connect(function(player)
		tagsThisRound[player] = nil
		lastMove[player] = nil
		friendInServer[player] = nil
	end)
	task.spawn(refreshFriends)

	-- A minute of play: everyone still in a live game.
	task.spawn(function()
		while true do
			task.wait(60)
			local phase = GameState.getPhase()
			if phase == "Playing" or phase == "Intro" then
				for _, player in Participants.alive() do
					Progression.record(player, "PlayMinute")
				end
			end
		end
	end)
end

return Progression
