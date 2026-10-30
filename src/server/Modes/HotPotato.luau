--!strict
-- Game mode: Hot Potato tag. At the start of a round as many players are It as the round's
-- elimination target (GameLoop works it out: shared/RoundPlan). Tagging passes It on
-- (server/TagService). When the round timer runs out, the Its are eliminated.
--
-- Every game mode has the same shape (see GameLoop):
--   Name: string
--   setup(players, target) -> status text   (assign roles at the start of a round; `target` is
--                                            how many will go out, and so how many are It)
--   finish(players, quota) -> eliminated     (who is out when the round timer ends, at most
--                                            `quota` of them: some of the target may already
--                                            be out. The Its who have held it longest go first)
local Roles = require(script.Parent.Parent.Roles)

local HotPotato = {
	Name = "Hot Potato",
}

function HotPotato.setup(players: { Player }, target: number): string
	local shuffled = table.clone(players)
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local its = math.clamp(target, 1, math.max(#shuffled - 1, 1))
	for i, player in shuffled do
		Roles.set(player, if i <= its then "It" else "Runner")
	end
	return if its == 1
		then "1 player is It. Don't be It when time runs out!"
		else `{its} players are It. Don't be It when time runs out!`
end

function HotPotato.finish(players: { Player }, quota: number): { Player }
	local its = {}
	for _, player in players do
		if Roles.get(player) == "It" then
			table.insert(its, player)
		end
	end
	-- Whoever has been It the longest is the one who failed to pass it on.
	table.sort(its, function(a, b)
		return Roles.heldFor(a) > Roles.heldFor(b)
	end)
	while #its > math.max(quota, 0) do
		table.remove(its)
	end
	return its
end

return HotPotato
