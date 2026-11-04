--!strict
-- Left click (or the gamepad right trigger) swings, for anyone: It's swing tags a Runner, any
-- other swing shoves whoever is in reach. Your swipe plays straight away (in first person too:
-- you see your own arm swipe), and the server decides what it hit (server/TagService). When
-- anyone swings, the server tells every client, and each one plays
-- the swipe on that player's character, so everyone sees it (the swipe is built in code, so
-- it has to be played on each screen).
-- Your screen picks who you hit, from what you see (the server sees everyone a ping late): the
-- player nearest the aim ring within Config.Tag.AimRange and AimAngle, else the nearest within
-- PlayerRange (Runners only while you're It in a round). The server checks it's in reach there
-- too. A swing that finds nobody stays live for Window: the first one to come into reach is hit.
-- While you're It the aim ring turns red whenever a Runner is in reach (Cursor.setHot).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Contestant = require(Shared:WaitForChild("Contestant"))
local GameState = require(Shared:WaitForChild("GameState"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local Cursor = require(script.Parent.Cursor)

local GAME_PHASES = { Intro = true, Playing = true, Results = true }

local TagSwing = {}

local animation: Animation? = nil

-- Wind up, reach forward, hold the reach; the track is faded out after SwingTime.
local function getAnimation(): Animation
	if not animation then
		local settings = Config.Tag
		local poses = settings.Poses :: { [string]: AnimationBuilder.Angles }
		animation = AnimationBuilder.make({
			{ time = 0, angles = poses.WindUp, ease = "In" },
			{ time = settings.SwingTime * 0.3, angles = poses.Reach, ease = "Out" },
			{ time = settings.SwingTime + 1, angles = poses.Reach },
		}, true)
	end
	return animation :: Animation
end

-- Plays the swipe on a humanoid (on this screen): any player's, or the Locker's preview.
function TagSwing.swipe(humanoid: Humanoid)
	local track = AnimationBuilder.load(humanoid, getAnimation())
	track:Play(0.04)
	task.delay(Config.Tag.SwingTime, function()
		track:Stop(0.15)
		task.delay(0.3, track.Destroy, track) -- after the fade-out finishes
	end)
end

-- Plays the swipe on any player's (or bot's) character.
local function playSwipe(player: Player)
	local character = Contestant.character(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	TagSwing.swipe(humanoid)
end

-- Does your swing tag right now (you're It in a round), or only shove?
local function tagging(player: Player): boolean
	local phase = GameState.getPhase()
	return player:GetAttribute("Role") == "It" and (phase == "Playing" or phase == "Sandbox")
end

-- Who your swing would hit now, as your screen sees it (nil: nobody in reach).
local function pick(player: Player, runnersOnly: boolean): any?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil
	end
	local settings = Config.Tag
	local inGame = GAME_PHASES[GameState.getPhase()] ~= nil
	local look = camera.CFrame.LookVector
	local eye = camera.CFrame.Position
	local cone = math.cos(math.rad(settings.AimAngle))
	local aimed, aimedDot = nil, -math.huge
	local near, nearDistance = nil, math.huge
	for _, other in Contestant.all() do
		if other == player then
			continue
		end
		if runnersOnly and other:GetAttribute("Role") ~= "Runner" then
			continue
		end
		if inGame and other:GetAttribute("Alive") ~= true then
			continue
		end
		local body = Contestant.character(other)
		local humanoid = body and body:FindFirstChildOfClass("Humanoid")
		local theirs = body and body:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not body or not humanoid or humanoid.Health <= 0 or not theirs then
			continue
		end
		if body:GetAttribute("Parked") then
			continue
		end
		local distance = (theirs.Position - root.Position).Magnitude
		if distance <= settings.PlayerRange and distance < nearDistance then
			near, nearDistance = other, distance
		end
		if distance <= settings.AimRange then
			local toward = theirs.Position - eye
			local dot = if toward.Magnitude > 0.01 then look:Dot(toward.Unit) else 1
			if dot >= cone and dot > aimedDot then
				aimed, aimedDot = other, dot
			end
		end
	end
	return aimed or near
end

function TagSwing.start()
	local player = Players.LocalPlayer
	local settings = Config.Tag
	local swingRemote = Remotes.get("TagSwing")
	local lastSwing = -math.huge

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonR2
		if not click then
			return
		end
		-- Anyone swings (It's swing tags, anyone else's shoves), just not while frozen.
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or humanoid.WalkSpeed <= 0 then
			return
		end
		local now = os.clock()
		if now - lastSwing < settings.Cooldown then
			return
		end
		lastSwing = now
		playSwipe(player) -- right away, no waiting for the server
		local tags = tagging(player)
		local target = pick(player, tags)
		swingRemote:FireServer(target)
		if target or not tags then
			return
		end
		-- Hit nobody: the swing stays live a moment for a Runner coming into reach.
		local swungAt = now
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			if os.clock() - swungAt > settings.Window or lastSwing ~= swungAt then
				connection:Disconnect()
				return
			end
			local late = tagging(player) and pick(player, true)
			if late then
				connection:Disconnect()
				swingRemote:FireServer(late, true)
			end
		end)
	end)

	-- While you're It in a round: the aim ring turns red when a Runner is in reach.
	RunService.Heartbeat:Connect(function()
		Cursor.setHot(tagging(player) and pick(player, true) ~= nil)
	end)

	-- Other players' swings (ours already played).
	Remotes.get("TagSwingPlayed").OnClientEvent:Connect(function(swinger: Player)
		if swinger ~= player then
			playSwipe(swinger)
		end
	end)
end

return TagSwing
