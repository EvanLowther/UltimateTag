--!strict
-- AFK check. While a round's timer is running (the Playing phase: never the intro freeze), a
-- player still in the game who shows no activity for Config.Afk.Time seconds is put out
-- (GameLoop listens with onAfk). The server can't see input, so activity is either a ping from
-- the client (client/Activity sends the Activity remote when you pressed or moved something) or
-- the character's body moving more than Config.Afk.MoveDistance studs between two checks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local GameLog = require(script.Parent.GameLog)
local Participants = require(script.Parent.Participants)
local Roles = require(script.Parent.Roles)

local Afk = {}

local active = false
local lastActive: { [Player]: number } = {}
local lastPosition: { [Player]: Vector3 } = {}
local listeners: { (Player) -> () } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function touch(player: Player)
	lastActive[player] = os.clock()
	local root = rootOf(player)
	lastPosition[player] = if root then root.Position else nil
end

-- Starts watching these players (the round timer just started): everyone counts as active now.
function Afk.begin(players: { Player })
	table.clear(lastActive)
	table.clear(lastPosition)
	for _, player in players do
		touch(player)
	end
	active = true
end

function Afk.stop()
	active = false
	table.clear(lastActive)
	table.clear(lastPosition)
end

-- Calls `listener(player)` when someone has been AFK too long.
function Afk.onAfk(listener: (Player) -> ())
	table.insert(listeners, listener)
end

local function check()
	local now = os.clock()
	for _, player in Participants.alive() do
		if Roles.isFrozen(player) then
			touch(player) -- frozen (the dev panel): they can't do anything
			continue
		end
		local root = rootOf(player)
		local before = lastPosition[player]
		if root and before and (root.Position - before).Magnitude > Config.Afk.MoveDistance then
			touch(player)
		elseif root and not before then
			lastPosition[player] = root.Position
		end
		local seen = lastActive[player]
		if seen == nil then
			touch(player) -- joined the game's list late (never happens mid-round, but be safe)
		elseif now - seen >= Config.Afk.Time then
			GameLog.say(`{player.Name} has been AFK for {Config.Afk.Time}s`)
			lastActive[player] = now -- (they are out next; this only stops a second report)
			for _, listener in listeners do
				task.spawn(listener, player)
			end
		end
	end
end

function Afk.start()
	Remotes.get("Activity").OnServerEvent:Connect(function(player)
		if active and lastActive[player] then
			lastActive[player] = os.clock()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastActive[player] = nil
		lastPosition[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Afk.CheckInterval)
			if active then
				check()
			end
		end
	end)
end

return Afk
