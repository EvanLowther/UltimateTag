--!strict
-- The game's calendar for daily and weekly things (login streak, quests, the shop's rotation):
-- days and weeks in UTC, so they change at the same moment for everyone (00:00 UTC; weeks start
-- on Monday). The dev panel can move time forward (a DevTimeOffset attribute on
-- ReplicatedStorage, Studio only) to test tomorrow without waiting; both sides read it, so
-- countdowns on screen match the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DayClock = {}

local DAY = 86400

-- Seconds since 1970 (UTC), plus the dev offset.
function DayClock.now(): number
	local offset = ReplicatedStorage:GetAttribute("DevTimeOffset")
	return os.time() + (if type(offset) == "number" then offset else 0)
end

-- Today's number (days since 1970, UTC).
function DayClock.day(): number
	return DayClock.now() // DAY
end

-- This week's number. 1 January 1970 was a Thursday, so +3 makes weeks start on Monday.
function DayClock.week(): number
	return (DayClock.day() + 3) // 7
end

function DayClock.secondsToNextDay(): number
	return DAY - DayClock.now() % DAY
end

function DayClock.secondsToNextWeek(): number
	local dayOfWeek = (DayClock.day() + 3) % 7 -- 0 = Monday
	return (6 - dayOfWeek) * DAY + DayClock.secondsToNextDay()
end

-- "5h 12m" / "2d 4h" / "48s".
function DayClock.format(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= DAY then
		return `{seconds // DAY}d {(seconds % DAY) // 3600}h`
	elseif seconds >= 3600 then
		return `{seconds // 3600}h {(seconds % 3600) // 60}m`
	elseif seconds >= 60 then
		return `{seconds // 60}m {seconds % 60}s`
	end
	return `{seconds}s`
end

return DayClock
