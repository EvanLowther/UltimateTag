--!strict
-- Dev panel, Progress tab: your saved profile at a glance, and tools for testing progression:
-- give coins, reset your profile, and move the game calendar forward (to test the login streak,
-- daily and weekly quests, and the shop's daily rotation without waiting).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayClock = require(Shared:WaitForChild("DayClock"))
local Profile = require(script.Parent.Parent.Profile)
local Widgets = require(script.Parent.Widgets)

local ProgressTab = {}

function ProgressTab.build(page: Instance, send: (string, ...any) -> ())
	Widgets.section(page, "Profile")
	local summary = Widgets.label(page, "Loading...")

	Widgets.section(page, "Coins")
	local coins = Widgets.row(page)
	for _, amount in { 100, 1000, 10000 } do
		Widgets.button(coins, `+{amount}`, function()
			send("GiveCoins", amount)
		end)
	end
	Widgets.button(coins, "Zero", function()
		local profile = Profile.get()
		if profile then
			send("GiveCoins", -profile.Coins)
		end
	end)

	Widgets.section(page, "XP")
	local xp = Widgets.row(page)
	for _, amount in { 50, 500, 5000 } do
		Widgets.button(xp, `+{amount} XP`, function()
			send("GiveXP", amount)
		end)
	end

	Widgets.section(page, "Calendar")
	local clock = Widgets.label(page, "")
	local time = Widgets.row(page)
	Widgets.button(time, "+1 hour", function()
		send("AdvanceTime", 3600)
	end)
	Widgets.button(time, "+1 day", function()
		send("AdvanceTime", 86400)
	end)
	Widgets.button(time, "+1 week", function()
		send("AdvanceTime", 86400 * 7)
	end)
	Widgets.button(page, "Back to real time", function()
		send("ResetTime")
	end)

	Widgets.section(page, "Cosmetics")
	local cosmetics = Widgets.row(page)
	Widgets.button(cosmetics, "Unlock all", function()
		send("UnlockAll")
	end)
	Widgets.button(cosmetics, "+1 free crate", function()
		send("GiveCrate")
	end)
	Widgets.button(page, "Finish my quests", function()
		send("CompleteQuests")
	end)

	Widgets.section(page, "Danger")
	Widgets.button(page, "Reset my profile", function()
		send("ResetProfile")
	end)

	local function refresh()
		local profile = Profile.get()
		if profile then
			local stats = profile.Stats
			summary.Text = table.concat({
				`Coins <b>{profile.Coins}</b>   Level <b>{profile.Level}</b>   XP <b>{profile.XP}</b>`,
				`Wins {stats.Wins}   Tags {stats.Tags}   Rounds survived {stats.RoundsSurvived}`,
				`Games {stats.GamesPlayed}   Streak {profile.Streak.Count}`,
			}, "\n")
		end
		local offset = (ReplicatedStorage:GetAttribute("DevTimeOffset") or 0) :: number
		clock.Text = `Day {DayClock.day()}   offset {offset // 86400}d {(offset % 86400) // 3600}h`
			.. `   next day in {DayClock.format(DayClock.secondsToNextDay())}`
	end
	Profile.onChanged(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("DevTimeOffset"):Connect(refresh)
	refresh()
end

return ProgressTab
