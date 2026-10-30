--!strict
-- The numbers behind a game's pacing, as pure functions (no Roblox services), so they can be
-- checked with Lune (`lune run tools/roundplan-test.luau` prints the schedule and asserts that
-- no game takes more than Config.Game.MaxRounds rounds).
--
-- Elimination target. Each round a share of the n players left go out, about a third, more in
-- big games so the game never takes more than `maxRounds` rounds:
--     out = clamp(round(n * max(1/3, 1 - n^(-1 / roundsLeft))), 1, n - 1)
--     roundsLeft = max(maxRounds - round + 1, 1)      (with 2 players left, exactly 1 goes out)
-- The number of Its at the start of a round equals this target, and the round ends early the
-- moment that many players are out. Resulting games (players left after each round, 5 rounds):
--     start  2: 1
--     start  4: 3, 2, 1
--     start  6: 4, 3, 2, 1
--     start  8: 5, 3, 2, 1
--     start 12: 7, 4, 3, 2, 1
--     start 20: 11, 6, 3, 2, 1
--     start 30: 15, 8, 4, 2, 1
--
-- Lobby countdown: starts at `LobbyCountdown` (20) when enough players are waiting; each player
-- who joins adds `JoinExtend` (10), but the clock never goes above `CountdownCap` (40); leavers
-- never add time; with `BigLobby` (10) or more players there are no extensions and the time left
-- is cut to `BigLobbyCut` (15) at most.
local RoundPlan = {}

-- The settings the countdown functions read (Config.Game has them).
export type CountdownSettings = {
	LobbyCountdown: number,
	JoinExtend: number,
	CountdownCap: number,
	BigLobby: number,
	BigLobbyCut: number,
}

-- One band of round lengths: this many players left or more get `Seconds`.
export type TimeBand = { From: number, Seconds: number }

-- How many of the `players` left go out this `round` (1 is the first), so that the game takes
-- at most `maxRounds` rounds. At least 1, at most players - 1; exactly 1 with 2 players.
function RoundPlan.eliminateTarget(players: number, round: number, maxRounds: number): number
	if players <= 2 then
		return 1
	end
	local roundsLeft = math.max(maxRounds - round + 1, 1)
	local share = math.max(1 / 3, 1 - players ^ (-1 / roundsLeft))
	local out = math.floor(players * share + 0.5)
	return math.clamp(out, 1, players - 1)
end

-- The whole schedule for a game starting with `players`: players left after each round.
function RoundPlan.schedule(players: number, maxRounds: number): { number }
	local left: { number } = {}
	local n = players
	local round = 0
	while n > 1 and round < maxRounds + 10 do -- (the bound only guards against a bad schedule)
		round += 1
		n -= RoundPlan.eliminateTarget(n, round, maxRounds)
		table.insert(left, n)
	end
	return left
end

-- Seconds a round lasts with `players` left: the first band (bands go from most players to
-- fewest) whose `From` is reached; the last band for anything smaller.
function RoundPlan.roundTime(players: number, bands: { TimeBand }): number
	for _, band in bands do
		if players >= band.From then
			return band.Seconds
		end
	end
	return bands[#bands].Seconds
end

-- Seconds the lobby countdown starts at with `players` waiting.
function RoundPlan.initialCountdown(players: number, settings: CountdownSettings): number
	local seconds = settings.LobbyCountdown
	if players >= settings.BigLobby then
		seconds = math.min(seconds, settings.BigLobbyCut)
	end
	return seconds
end

-- The countdown's seconds left after `joins` players joined while it ran and there are now
-- `players` waiting. A big lobby has no extensions and cuts the time left; otherwise each join
-- adds JoinExtend up to the cap (never taking time away, never adding past the cap).
function RoundPlan.countdownAfter(
	remaining: number,
	joins: number,
	players: number,
	settings: CountdownSettings
): number
	if players >= settings.BigLobby then
		return math.min(remaining, settings.BigLobbyCut)
	end
	if joins <= 0 then
		return remaining
	end
	local extended = math.min(remaining + joins * settings.JoinExtend, settings.CountdownCap)
	return math.max(remaining, extended)
end

return RoundPlan
