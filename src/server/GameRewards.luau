--!strict
-- What each player earned during one game, for the win screen (client/WinScreen). Progression
-- (the economy's module) pays and records; this only watches each profile change while a game
-- is on:
--   Coins and crates: every increase is added up (spending them in the shop in between doesn't
--   take anything off).
--   XP: the difference in total XP (levels counted) from the start to the end of the game.
--   Items: ids owned at the end that were not at the start.
-- Not exact in one way: anything else the player collects during the game (claiming a quest or
-- the daily streak from the menu while spectating) is counted too.
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)

local GameRewards = {}

export type Earned = {
	Coins: number,
	XP: number,
	Crates: number,
	Items: { string },
	LevelFrom: number,
	LevelTo: number,
}

type Tracker = {
	coins: number, -- coins as of the last change
	crates: number,
	gained: { coins: number, crates: number },
	startXP: number, -- total XP at the start
	startLevel: number,
	owned: { [string]: boolean },
}

local trackers: { [Player]: Tracker } = {}

-- All the XP a profile has earned in its life: the levels it has finished plus the current bar.
local function totalXP(profile: PlayerData.Profile): number
	local total = profile.XP :: number
	for level = 1, (profile.Level :: number) - 1 do
		total += Progression.xpForLevel(level)
	end
	return total
end

-- Starts counting for these players (call when a game starts; replaces any earlier count).
function GameRewards.begin(players: { Player })
	table.clear(trackers)
	for _, player in players do
		local profile = PlayerData.get(player)
		if profile then
			trackers[player] = {
				coins = profile.Coins,
				crates = profile.Crates,
				gained = { coins = 0, crates = 0 },
				startXP = totalXP(profile),
				startLevel = profile.Level,
				owned = table.clone(profile.Owned),
			}
		end
	end
end

-- What this player earned since `begin` (nil if they weren't counted, for example no profile).
function GameRewards.earned(player: Player): Earned?
	local tracker = trackers[player]
	local profile = PlayerData.get(player)
	if not tracker or not profile then
		return nil
	end
	local items = {}
	for id in profile.Owned do
		if not tracker.owned[id] then
			table.insert(items, id)
		end
	end
	table.sort(items)
	return {
		Coins = tracker.gained.coins,
		XP = math.max(totalXP(profile) - tracker.startXP, 0),
		Crates = tracker.gained.crates,
		Items = items,
		LevelFrom = tracker.startLevel,
		LevelTo = profile.Level,
	}
end

-- Stops counting.
function GameRewards.clear()
	table.clear(trackers)
end

function GameRewards.start()
	PlayerData.onChanged(function(player, profile)
		local tracker = trackers[player]
		if not tracker then
			return
		end
		tracker.gained.coins += math.max(profile.Coins - tracker.coins, 0)
		tracker.gained.crates += math.max(profile.Crates - tracker.crates, 0)
		tracker.coins = profile.Coins
		tracker.crates = profile.Crates
	end)
	Players.PlayerRemoving:Connect(function(player)
		trackers[player] = nil
	end)
end

return GameRewards
