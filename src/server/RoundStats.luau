--!strict
-- Each player's numbers for the round being played, for the results card (client/RoundResults):
-- tags landed, times tagged, and seconds spent as It. GameLoop calls `reset` at a round's
-- start, `begin` when the round timer starts and `finish` when it ends; TagService calls
-- `tagged`; role changes (Roles) close and open the It stopwatch. Outside that window nothing
-- is counted.
local Players = game:GetService("Players")

local Roles = require(script.Parent.Roles)

local RoundStats = {}

export type Stats = { Tags: number, Tagged: number, ItSeconds: number }

local counting = false
local stats: { [Player]: Stats } = {}
local itSince: { [Player]: number } = {}

local function statsFor(player: Player): Stats
	local mine = stats[player]
	if not mine then
		mine = { Tags = 0, Tagged = 0, ItSeconds = 0 }
		stats[player] = mine
	end
	return mine
end

local function stopClock(player: Player)
	local since = itSince[player]
	if since then
		statsFor(player).ItSeconds += os.clock() - since
		itSince[player] = nil
	end
end

-- A new round: clears the last round's numbers (and counts nothing until `begin`).
function RoundStats.reset(players: { Player })
	table.clear(stats)
	table.clear(itSince)
	counting = false
	for _, player in players do
		statsFor(player)
	end
end

-- The round timer started: count tags and time as It from now.
function RoundStats.begin()
	counting = true
	for _, player in Players:GetPlayers() do
		if Roles.get(player) == "It" then
			itSince[player] = os.clock()
		end
	end
end

-- Stops counting (the round timer ended). The numbers stay until the next `begin`.
function RoundStats.finish()
	if not counting then
		return
	end
	for player in itSince do
		stopClock(player)
	end
	counting = false
end

function RoundStats.tagged(tagger: Player, tagged: Player)
	if counting then
		statsFor(tagger).Tags += 1
		statsFor(tagged).Tagged += 1
	end
end

function RoundStats.get(player: Player): Stats
	return statsFor(player)
end

function RoundStats.start()
	Roles.onChanged(function(player, _old, new)
		if not counting then
			return
		end
		if new == "It" then
			itSince[player] = itSince[player] or os.clock()
		else
			stopClock(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		itSince[player] = nil
		stats[player] = nil
	end)
end

return RoundStats
