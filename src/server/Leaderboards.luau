--!strict
-- The leaderboards in the menu's Leaders window: the top players by Wins, Tags, Level and Wall
-- runs (Config.Leaderboards), all time and this week. Each board is an OrderedDataStore:
-- all-time wins are WinsStore's "TotalWins_v1" (WinsStore writes it on every win); the others
-- are "Board_<Id>_v1", and the weekly ones "Board_<Id>_W<week>_v1", a fresh list every Monday
-- 00:00 UTC (shared/DayClock), counted from each player's profile Weekly counts (kept up to
-- date here from Progression events).
--   Writing: every FlushSeconds, each player's values that changed since they were written.
--   Reading: one board every RefreshSeconds, round robin, its top TopCount kept in a cache.
--   Clients ask with the Leaderboard remote; the reply has each board's top ShowCount plus the
--   asking player's own rank (when they're in the top TopCount) and value.
-- Without data stores (Studio with API access off) the boards list this server's players.
-- Boards with Menu = false (Coins) aren't in the window: the lobby's boards read them with
-- Leaderboards.top (server/LobbyBoards).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DayClock = require(Shared.DayClock)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)

local Leaderboards = {}

export type Entry = { UserId: number, Name: string?, Value: number }
type Board = { key: string, id: string, stat: string, weekly: boolean }

local KEY_PREFIX = "Player_"
local WEEKLY_EVENTS = { Win = "Wins", Tag = "Tags", WallRun = "WallRuns" }
local ASK_GAP = 2 -- seconds between a player's requests

local storesOn = true
local cache: { [string]: { Entry } } = {} -- board key -> top entries (global, saved boards)
local written: { [Player]: { [string]: number } } = {}
local lastAsk: { [Player]: number } = {}
local names: { [number]: string } = {}

local boards: { Board } = {}
for _, def in Config.Leaderboards.Boards do
	table.insert(boards, { key = `{def.Id}:All`, id = def.Id, stat = def.Stat, weekly = false })
	if def.Weekly then
		table.insert(boards, { key = `{def.Id}:Week`, id = def.Id, stat = def.Stat, weekly = true })
	end
end

local function turnOff(reason: any)
	if storesOn then
		storesOn = false
		warn(`[Leaderboards] Saved boards are off ({reason}); showing this server's players.`)
	end
end

local function storeName(board: Board): string
	if board.id == "Wins" and not board.weekly then
		return "TotalWins_v1" -- shared with WinsStore (and the lobby leaderboard)
	end
	return if board.weekly then `Board_{board.id}_W{DayClock.week()}_v1` else `Board_{board.id}_v1`
end

local function storeFor(board: Board): OrderedDataStore?
	if not storesOn then
		return nil
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName(board))
	end)
	if not ok then
		turnOff(result)
		return nil
	end
	return result
end

-- Starts the player's weekly counts over when a new week has begun.
local function rollWeek(profile: PlayerData.Profile)
	local week = DayClock.week()
	if profile.Weekly.Week ~= week then
		profile.Weekly = { Week = week, Wins = 0, Tags = 0, WallRuns = 0 }
	end
end

-- A player's value on a board, from their profile.
local function valueFor(profile: PlayerData.Profile, board: Board): number
	if board.weekly then
		local weekly = profile.Weekly
		return if weekly.Week == DayClock.week() then weekly[board.stat] or 0 else 0
	elseif board.stat == "Level" then
		return profile.Level
	elseif board.stat == "Coins" then
		return profile.Coins
	end
	return profile.Stats[board.stat] or 0
end

local function nameFor(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then name else `Player {userId}`
	return names[userId]
end

-- Writes each player's changed values.
local function flush()
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		if not profile or not storesOn then
			continue
		end
		local done = written[player] or {}
		written[player] = done
		for _, board in boards do
			if board.id == "Wins" and not board.weekly then
				continue -- WinsStore writes all-time wins itself
			end
			local value = valueFor(profile, board)
			local mark = if board.weekly then `{board.key}@{DayClock.week()}` else board.key
			if value <= 0 or done[mark] == value then
				continue
			end
			local store = storeFor(board)
			if not store then
				return
			end
			local ok, err = pcall(function()
				store:SetAsync(KEY_PREFIX .. player.UserId, value)
			end)
			if ok then
				done[mark] = value
			else
				local text = tostring(err)
				if
					string.find(text, "API", 1, true)
					or string.find(text, "publish", 1, true)
					or string.find(text, "403", 1, true)
				then
					turnOff(err)
					return
				end
			end
		end
	end
end

-- Reads one board's top list into the cache.
local function read(board: Board)
	local store = storeFor(board)
	if not store then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, Config.Leaderboards.TopCount):GetCurrentPage()
	end)
	if not ok then
		local text = tostring(page)
		if
			string.find(text, "API", 1, true)
			or string.find(text, "publish", 1, true)
			or string.find(text, "403", 1, true)
		then
			turnOff(page)
		end
		return
	end
	local entries: { Entry } = {}
	for i, item in page do
		local userId = tonumber(string.sub(item.key, #KEY_PREFIX + 1))
		if userId then
			table.insert(entries, {
				UserId = userId,
				Name = if i <= Config.Leaderboards.ShowCount then nameFor(userId) else nil,
				Value = item.value,
			})
		end
	end
	cache[board.key] = entries
end

-- This server's players on a board (when saved boards are off).
local function serverBoard(board: Board): { Entry }
	local entries: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		if profile then
			table.insert(
				entries,
				{ UserId = player.UserId, Name = player.Name, Value = valueFor(profile, board) }
			)
		end
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	return entries
end

local function reply(player: Player)
	local profile = PlayerData.get(player)
	local show = Config.Leaderboards.ShowCount
	local result = {}
	local mine = {}
	for _, board in boards do
		local entries = if storesOn then cache[board.key] or {} else serverBoard(board)
		local top = {}
		local rank: number? = nil
		for i, entry in entries do
			if i <= show then
				table.insert(top, entry)
			end
			if entry.UserId == player.UserId then
				rank = i
			end
		end
		result[board.key] = top
		mine[board.key] = {
			Rank = rank,
			Value = if profile then valueFor(profile, board) else 0,
		}
	end
	Remotes.get("Leaderboard"):FireClient(player, {
		Source = if storesOn then "global" else "server",
		Boards = result,
		Me = mine,
		WeekEndsIn = DayClock.secondsToNextWeek(),
	})
end

-- A board's all-time top list, read fresh, and where it came from: "global" (saved) or "server"
-- (saving is off: this server's players). Names are filled in for the top ShowCount. Yields.
function Leaderboards.top(id: string): ({ Entry }, string)
	for _, board in boards do
		if board.id == id and not board.weekly then
			if storesOn then
				read(board)
			end
			if storesOn then
				return cache[board.key] or {}, "global"
			end
			return serverBoard(board), "server"
		end
	end
	return {}, "server"
end

function Leaderboards.start()
	-- Weekly counts, from the events that feed the weekly boards.
	Progression.onRecord(function(player, event, amount)
		local stat = WEEKLY_EVENTS[event]
		if stat then
			PlayerData.update(player, function(profile)
				rollWeek(profile)
				profile.Weekly[stat] += amount
			end)
		end
	end)
	PlayerData.onLoaded(function(player, profile)
		names[player.UserId] = player.Name
		if profile.Weekly.Week ~= DayClock.week() then
			PlayerData.update(player, rollWeek)
		end
	end)
	Remotes.get("Leaderboard").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastAsk[player] or -math.huge) < ASK_GAP then
			return
		end
		lastAsk[player] = now
		reply(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		written[player] = nil
		lastAsk[player] = nil
	end)

	task.spawn(function()
		local index = 0
		while true do
			if storesOn then
				index = index % #boards + 1
				read(boards[index])
			end
			task.wait(Config.Leaderboards.RefreshSeconds)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Leaderboards.FlushSeconds)
			flush()
		end
	end)
	game:BindToClose(flush)
end

return Leaderboards
