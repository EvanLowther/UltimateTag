--!strict
-- Lifetime wins, saved between sessions (DataStore "Wins_v1"), and the all-time top list the
-- lobby leaderboard shows (OrderedDataStore "TotalWins_v1").
-- Saving needs Roblox's data stores: a published place, and in Studio "Enable Studio Access to
-- API Services" (Game Settings > Security). Without them it keeps working for the session:
-- wins count until you leave, and the leaderboard shows the players in this server.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderstats = require(script.Parent.Leaderstats)

local WinsStore = {}

export type Entry = { name: string, wins: number }

local KEY_PREFIX = "Player_"

local savingOn = true
local winsStore: DataStore? = nil
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

local function stores(): (DataStore?, OrderedDataStore?)
	if savingOn and not winsStore then
		local ok, result = pcall(function()
			return {
				DataStoreService:GetDataStore("Wins_v1"),
				DataStoreService:GetOrderedDataStore("TotalWins_v1"),
			}
		end)
		if ok then
			winsStore, topStore = result[1] :: DataStore, result[2] :: OrderedDataStore
		else
			turnOff(result)
		end
	end
	return winsStore, topStore
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

-- Loads a player's lifetime wins into their Wins column.
local function load(player: Player)
	names[player.UserId] = player.Name
	local store = stores()
	if not store then
		return
	end
	local ok, value = pcall(function()
		return store:GetAsync(KEY_PREFIX .. player.UserId)
	end)
	if not ok then
		turnOff(value)
		return
	end
	if player.Parent then
		Leaderstats.set(player, "Wins", tonumber(value) or 0)
	end
end

-- Adds a win: in the Wins column right away, and to the saved total and the top list.
function WinsStore.addWin(player: Player)
	Leaderstats.add(player, "Wins", 1)
	local store, top = stores()
	if not store or not top then
		return
	end
	local key = KEY_PREFIX .. player.UserId
	task.spawn(function()
		local ok, total = pcall(function()
			return store:UpdateAsync(key, function(old)
				return (tonumber(old) or 0) + 1
			end)
		end)
		if not ok then
			turnOff(total)
			return
		end
		pcall(function()
			top:SetAsync(key, total)
		end)
	end)
end

-- The top `count` players by lifetime wins, and where the list came from: "global" (saved,
-- all-time) or "server" (saving is off: the players in this server, by this session's wins).
function WinsStore.top(count: number): ({ Entry }, string)
	local _, top = stores()
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
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return WinsStore
