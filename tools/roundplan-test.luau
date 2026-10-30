-- Prints the elimination schedule for 2 to 30 players and checks the rules in
-- src/shared/RoundPlan.luau: no game takes more than 5 rounds, each round at least 1 and at
-- most n - 1 go out, and the lobby countdown follows its rules.
--   lune run tools/roundplan-test.luau
local process = require("@lune/process")
local RoundPlan = require("../src/shared/RoundPlan")

local MAX_ROUNDS = 5
local failed = 0
local function check(ok: boolean, message: string)
	if not ok then
		failed += 1
		print("FAIL " .. message)
	end
end

print("players: players left after each round")
for players = 2, 30 do
	local left = RoundPlan.schedule(players, MAX_ROUNDS)
	print(string.format("%2d: %s", players, table.concat(left, ", ")))
	check(#left <= MAX_ROUNDS, `{players} players take {#left} rounds`)
	check(left[#left] == 1, `{players} players do not end on 1`)
	local n = players
	for round, after in left do
		local out = n - after
		check(out >= 1 and out <= n - 1, `{players} players, round {round}: {out} out of {n}`)
		n = after
	end
end

-- A game that starts late in the schedule (players left, a later round) still finishes.
for players = 2, 30 do
	for round = 1, MAX_ROUNDS + 3 do
		local out = RoundPlan.eliminateTarget(players, round, MAX_ROUNDS)
		check(out >= 1 and out <= math.max(players - 1, 1), `target {players} players round {round}`)
	end
end

local bands = { { From = 7, Seconds = 120 }, { From = 3, Seconds = 90 }, { From = 2, Seconds = 90 } }
check(RoundPlan.roundTime(30, bands) == 120, "30 left")
check(RoundPlan.roundTime(7, bands) == 120, "7 left")
check(RoundPlan.roundTime(6, bands) == 90, "6 left")
check(RoundPlan.roundTime(3, bands) == 90, "3 left")
check(RoundPlan.roundTime(2, bands) == 90, "2 left")

local lobby = {
	LobbyCountdown = 20,
	JoinExtend = 10,
	CountdownCap = 40,
	BigLobby = 10,
	BigLobbyCut = 15,
}
check(RoundPlan.initialCountdown(2, lobby) == 20, "starts at 20")
check(RoundPlan.initialCountdown(12, lobby) == 15, "a big lobby starts cut")
check(RoundPlan.countdownAfter(18, 1, 3, lobby) == 28, "a join adds 10")
check(RoundPlan.countdownAfter(35, 1, 4, lobby) == 40, "the cap is 40")
check(RoundPlan.countdownAfter(40, 1, 5, lobby) == 40, "no more past the cap")
check(RoundPlan.countdownAfter(12, 0, 2, lobby) == 12, "leavers add nothing")
check(RoundPlan.countdownAfter(30, 1, 10, lobby) == 15, "10 players cut it to 15")
check(RoundPlan.countdownAfter(9, 1, 11, lobby) == 9, "a big lobby never extends")

print(if failed == 0 then "RoundPlan OK" else `{failed} check(s) failed`)
process.exit(if failed == 0 then 0 else 1)
