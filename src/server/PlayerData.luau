--!strict
-- Each player's saved profile: coins, XP and level, stats, cosmetics owned and equipped (and
-- Iridescent serial numbers), crates, login streak, quests, achievements, weekly counts. One DataStore entry per player ("Profiles_v1", key
-- "Player_<UserId>").
--   Session lock: loading writes this server's id into the profile, and other servers wait for
--   it to be released (on leave) or to go stale (Config.Data.LockStale, if a server crashed), so
--   two servers never overwrite each other.
--   Saved every Config.Data.AutosaveSeconds, when the player leaves, and when the server shuts.
--   Older saves (lifetime wins in "Wins_v1", the wheel's "WheelSpins_v1") are imported once.
--   Without data stores (Studio with API access off) it works for the session, with one warning.
-- Clients see their own profile through the ProfileSync remote (client/Profile), and everyone's
-- Coins, Level, XP and equipped cosmetics as Player attributes.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = {}

export type Profile = { [string]: any }

local KEY_PREFIX = "Player_"
local VERSION = 1

local profiles: { [Player]: Profile } = {}
local saveable: { [Player]: boolean } = {} -- false: a session-only profile (never written)
local syncQueued: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local changedCallbacks: { (Player, Profile) -> () } = {}

local storesOn = true
local profileStore: DataStore? = nil

local function turnOff(reason: any)
	if storesOn then
		storesOn = false
		warn(
			`[PlayerData] Saving is off ({reason}). Progress lasts for this session only. To save:`
				.. " publish the place, then Game Settings > Security > Enable Studio Access to API Services."
		)
	end
end

-- Errors that mean "data stores aren't available here at all" (not a passing hiccup).
local function unavailable(message: any): boolean
	local text = tostring(message)
	return string.find(text, "API", 1, true) ~= nil
		or string.find(text, "publish", 1, true) ~= nil
		or string.find(text, "403", 1, true) ~= nil
end

local function store(): DataStore?
	if storesOn and not profileStore then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("Profiles_v1")
		end)
		if ok then
			profileStore = result
		else
			turnOff(result)
		end
	end
	return if storesOn then profileStore else nil
end

-- A brand new profile.
function PlayerData.defaults(): Profile
	local equipped = Config.Progression.DefaultEquipped
	local owned = {}
	for _, item in equipped do
		owned[item] = true
	end
	return {
		Version = VERSION,
		Coins = 0,
		XP = 0,
		Level = 1,
		Stats = {
			Wins = 0,
			Tags = 0,
			RoundsSurvived = 0,
			GamesPlayed = 0,
			PlayMinutes = 0,
			WallRuns = 0,
			Slides = 0,
			Vaults = 0,
			Climbs = 0,
			WinStreak = 0,
			BestWinStreak = 0,
		},
		Owned = owned,
		Equipped = table.clone(equipped),
		Streak = { Count = 0, LastDay = -1 },
		Quests = { Day = -1, Daily = {}, Week = -1, Weekly = {} },
		Achievements = {},
		Wheel = { LastSpin = 0 },
		Crates = 0, -- crates waiting to be opened (bought or earned)
		Serials = {}, -- Iridescent item id -> its serial number (server/Serials)
		-- This week's counts for the weekly leaderboards (server/Leaderboards).
		Weekly = { Week = -1, Wins = 0, Tags = 0, WallRuns = 0 },
		FirstWinDay = -1,
		Migrated = false,
	}
end

-- Fills in anything missing from an older save (new fields added later), keeping what's there.
local function reconcile(data: Profile, defaults: Profile)
	for key, value in defaults do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

-- Imports the old separate saves once (lifetime wins, the wheel's last spin).
local function migrate(player: Player, data: Profile)
	if data.Migrated then
		return
	end
	local key = KEY_PREFIX .. player.UserId
	local ok, wins = pcall(function()
		return DataStoreService:GetDataStore("Wins_v1"):GetAsync(key)
	end)
	if ok and tonumber(wins) then
		data.Stats.Wins = math.max(data.Stats.Wins, tonumber(wins) :: number)
	end
	local ok2, spin = pcall(function()
		return DataStoreService:GetDataStore("WheelSpins_v1"):GetAsync(key)
	end)
	if ok2 and tonumber(spin) then
		data.Wheel.LastSpin = tonumber(spin)
	end
	data.Migrated = true
end

-- Sends the player their profile and updates the attributes everyone can read. Batched to once
-- per frame however many changes happen.
local function sync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		local profile = profiles[player]
		if not profile or not player.Parent then
			return
		end
		player:SetAttribute("Coins", profile.Coins)
		player:SetAttribute("Level", profile.Level)
		player:SetAttribute("XP", profile.XP)
		for kind, item in profile.Equipped do
			player:SetAttribute(`Equipped{kind}`, item)
		end
		local view = table.clone(profile)
		view.Session = nil
		Remotes.get("ProfileSync"):FireClient(player, view)
	end)
end

-- Loads (or creates) the profile, taking the session lock. Returns the profile and whether it
-- can be saved.
local function load(player: Player): (Profile?, boolean)
	local key = KEY_PREFIX .. player.UserId
	local settings = Config.Data
	for attempt = 1, settings.LoadAttempts do
		local s = store()
		if not s then
			break
		end
		local loaded: Profile? = nil
		local locked = false
		local ok, err = pcall(function()
			s:UpdateAsync(key, function(old: Profile?)
				local session = old and old.Session
				local takeOver = attempt == settings.LoadAttempts
				if
					session
					and session.Job ~= game.JobId
					and os.time() - (session.Time or 0) < settings.LockStale
					and not takeOver
				then
					locked = true
					return nil -- another server has it: leave it alone and try again
				end
				local data = old or PlayerData.defaults()
				reconcile(data, PlayerData.defaults())
				data.Session = { Job = game.JobId, Time = os.time() }
				loaded = data
				return data
			end)
		end)
		if not ok then
			if unavailable(err) then
				turnOff(err)
				break
			end
			warn(`[PlayerData] Loading {player.Name} failed (try {attempt}): {err}`)
		elseif loaded then
			return loaded, true
		elseif not locked then
			break
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(settings.RetryDelay)
	end
	if storesOn and store() then
		-- Data stores work but this profile wouldn't load: play on a fresh session-only profile
		-- and never write it, so the real save isn't overwritten.
		warn(`[PlayerData] Couldn't load {player.Name}'s data; this session won't be saved.`)
	end
	return PlayerData.defaults(), false
end

-- Writes the profile. `release` frees the session lock (leaving / shutting down).
local function save(player: Player, release: boolean)
	local profile = profiles[player]
	local s = store()
	if not profile or not saveable[player] or not s then
		return
	end
	local key = KEY_PREFIX .. player.UserId
	local ok, err = pcall(function()
		s:UpdateAsync(key, function(old: Profile?)
			local session = old and old.Session
			if session and session.Job ~= game.JobId then
				return nil -- another server took over (this one was too slow): don't clobber it
			end
			local data = table.clone(profile)
			data.Session = if release then nil else { Job = game.JobId, Time = os.time() }
			return data
		end)
	end)
	if not ok then
		warn(`[PlayerData] Saving {player.Name} failed: {err}`)
	end
end

local function onJoin(player: Player)
	local profile, canSave = load(player)
	if not profile or not player.Parent then
		return
	end
	if canSave then
		migrate(player, profile)
	end
	profiles[player] = profile
	saveable[player] = canSave
	sync(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

-- The player's profile, or nil while it's loading.
function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

-- Waits for the player's profile (nil if they leave first).
function PlayerData.waitFor(player: Player): Profile?
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Changes the player's profile: `change` edits it in place. Syncs to the client and tells
-- listeners. Does nothing until the profile is loaded.
function PlayerData.update(player: Player, change: (Profile) -> ())
	local profile = profiles[player]
	if not profile then
		return
	end
	change(profile)
	sync(player)
	for _, callback in changedCallbacks do
		task.spawn(callback, player, profile)
	end
end

-- Runs `callback(player, profile)` for each profile as it loads (and for ones already loaded).
function PlayerData.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

function PlayerData.onChanged(callback: (Player, Profile) -> ())
	table.insert(changedCallbacks, callback)
end

-- Dev panel: start this player over (keeps saving to the same key).
function PlayerData.reset(player: Player)
	if profiles[player] then
		local fresh = PlayerData.defaults()
		fresh.Migrated = true
		profiles[player] = fresh
		PlayerData.update(player, function() end)
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onJoin, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
		saveable[player] = nil
	end)
	-- The client asks again if it missed the first sync.
	Remotes.get("ProfileSync").OnServerEvent:Connect(function(player)
		if profiles[player] then
			sync(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not storesOn then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.2)
		end
	end)
end

return PlayerData
