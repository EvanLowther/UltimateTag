--!strict
-- Game mode: Hot Potato tag. About Config.Game.EliminateFraction of the players start as It
-- (at least 1, never everyone). Tagging passes It on (server/TagService). When the round timer
-- runs out, everyone who is still It is eliminated.
--
-- Every game mode has the same shape (see GameLoop):
--   Name: string
--   setup(players) -> status text   (assign roles at the start of a round)
--   finish(players) -> eliminated   (who is out when the round timer ends)
--   canContinue(players) -> boolean (false ends the round early: nothing left to play for)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Roles = require(script.Parent.Parent.Roles)

local HotPotato = {
	Name = "Hot Potato",
}

-- How many players start as It.
function HotPotato.itCount(playerCount: number): number
	local count = math.floor(playerCount * Config.Game.EliminateFraction + 0.5)
	return math.clamp(count, 1, math.max(playerCount - 1, 1))
end

function HotPotato.setup(players: { Player }): string
	local shuffled = table.clone(players)
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local its = HotPotato.itCount(#shuffled)
	for i, player in shuffled do
		Roles.set(player, if i <= its then "It" else "Runner")
	end
	return if its == 1
		then "1 player is It. Don't be It when time runs out!"
		else `{its} players are It. Don't be It when time runs out!`
end

-- The round is over early once no It is left (they fell off a FallEliminates map).
function HotPotato.canContinue(players: { Player }): boolean
	for _, player in players do
		if Roles.get(player) == "It" then
			return true
		end
	end
	return false
end

function HotPotato.finish(players: { Player }): { Player }
	local out = {}
	for _, player in players do
		if Roles.get(player) == "It" then
			table.insert(out, player)
		end
	end
	return out
end

return HotPotato
