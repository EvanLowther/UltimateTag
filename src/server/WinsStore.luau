--!strict
-- Lifetime wins: kept in each player's saved profile (server/PlayerData, Stats.Wins), shown in
-- the Wins column, and copied to the all-time top list the lobby leaderboard shows
-- (OrderedDataStore "TotalWins_v1").
-- Saving needs Roblox's data stores: a published place, and in Studio "Enable Studio Access to
-- API Services" (Game Settings > Security). Without them it keeps working for the session:
-- wins count until you leave, and the leaderboard shows the players in this server.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderstats = require(script.Parent.Leaderstats)
local PlayerData = require(script.Parent.PlayerData)

local WinsStore = {}

export type Entry = { name: string, wins: number }

local KEY_PREFIX = "Player_"

local savingOn = true
local topStore: OrderedDataStore? = nil
local names: { [number]: string } = {}

local function turnOff(reason: any)
	if savingOn then
		savingOn = false
		warn(
			`[WinsStore] Saving wins is off ({reason}). To turn it on: publish the place, then in Studio`
				.. " Game Settings > Security > Enable Studio Access to API Services."
		)
	end
end

local function topList(): OrderedDataStore?
	if savingOn and not topStore then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore("TotalWins_v1")
		end)
		if ok then
			topStore = result
		else
			turnOff(result)
		end
	end
	return topStore
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

-- Adds a win: to the profile (saved with it), the Wins column, and the top list.
function WinsStore.addWin(player: Player)
	local total = 0
	PlayerData.update(player, function(profile)
		profile.Stats.Wins += 1
		total = profile.Stats.Wins
	end)
	Leaderstats.set(player, "Wins", total)
	local top = topList()
	if not top then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			top:SetAsync(KEY_PREFIX .. player.UserId, total)
		end)
		if not ok then
			turnOff(err)
		end
	end)
end

-- The top `count` players by lifetime wins, and where the list came from: "global" (saved,
-- all-time) or "server" (saving is off: the players in this server, by this session's wins).
function WinsStore.top(count: number): ({ Entry }, string)
	local top = topList()
	if top then
		local ok, page = pcall(function()
			return top:GetSortedAsync(false, count):GetCurrentPage()
		end)
		if ok then
			local list: { Entry } = {}
			for _, item in page do
				local userId = tonumber(string.sub(item.key, #KEY_PREFIX + 1))
				table.insert(
					list,
					{ name = if userId then nameFor(userId) else "?", wins = item.value }
				)
			end
			return list, "global"
		end
		turnOff(page)
	end
	local list: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local folder = player:FindFirstChild("leaderstats")
		local wins = folder and folder:FindFirstChild("Wins")
		table.insert(
			list,
			{ name = player.Name, wins = if wins and wins:IsA("IntValue") then wins.Value else 0 }
		)
	end
	table.sort(list, function(a, b)
		return a.wins > b.wins
	end)
	while #list > count do
		table.remove(list)
	end
	return list, "server"
end

function WinsStore.start()
	PlayerData.onLoaded(function(player, profile)
		names[player.UserId] = player.Name
		Leaderstats.set(player, "Wins", profile.Stats.Wins)
	end)
end

return WinsStore
