--!strict
-- Touch a wall in the air and press jump within Config.WallBounce.Window to push off it: out
-- along the wall's normal and up, keeping some of your speed along the wall. Ledges you can
-- reach still mantle automatically; a running mantle blocks a bounce.
-- The push-off is sold with a camera kick (roll away from the wall, tip up), a kick-off body
-- animation, a hit and push sound, and the first-person hand planting on the wall (Viewmodel).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local CameraKick = require(script.Parent.CameraKick)
local MoveState = require(script.Parent.MoveState)

local WallBounce = {}

-- One partial animation per wall side, built on first use.
local animations: { [string]: Animation } = {}

-- "Left", "Right", "Front" or "Back": where the wall is relative to your body.
local function getAnimation(side: string): Animation
	local cached = animations[side]
	if cached then
		return cached
	end
	local settings = Config.WallBounce
	local poses = settings.Poses :: { [string]: AnimationBuilder.Angles }
	local contact, push
	if side == "Left" then
		contact, push = poses.SideContact, poses.SidePush
	elseif side == "Right" then
		contact, push =
			AnimationBuilder.mirror(poses.SideContact), AnimationBuilder.mirror(poses.SidePush)
	elseif side == "Front" then
		contact, push = poses.FrontContact, poses.FrontPush
	else
		contact, push = poses.BackContact, poses.BackPush
	end
	local pushAt = settings.ContactTime
	local animation = AnimationBuilder.make({
		{ time = 0, angles = contact },
		{ time = pushAt, angles = push },
		-- Held well past HoldTime; the track is faded out before it ends.
		{ time = pushAt + settings.HoldTime + 1, angles = push },
	}, true)
	animations[side] = animation
	return animation
end

local function playSound(parent: Instance, id: string, speed: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.PlaybackSpeed = speed
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 2)
end

function WallBounce.start()
	local settings = Config.WallBounce
	local wallNormal: Vector3? = nil -- the last wall touched in the air
	local wallTime = -math.huge
	local lastBounce = -math.huge
	local tracks: { [string]: AnimationTrack } = {}
	local trackHumanoid: Humanoid? = nil
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Wall contact: look the way you're moving and the way you're steering.
	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		if not parts or MoveState.isGrounded(parts.humanoid) then
			wallNormal = nil
			return
		end
		local root = parts.root
		params.FilterDescendantsInstances = { parts.character }
		local reach = root.Size.X / 2 + settings.Reach
		local directions = {
			MoveState.flat(root.AssemblyLinearVelocity),
			MoveState.flat(parts.humanoid.MoveDirection),
		}
		for _, dir in directions do
			if dir.Magnitude > 0.1 then
				local hit = workspace:Raycast(root.Position, dir.Unit * reach, params)
				if hit and math.abs(hit.Normal.Y) < 0.3 then
					wallNormal = MoveState.flat(hit.Normal).Unit
					wallTime = os.clock()
					return
				end
			end
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		if
			not wallNormal
			or now - wallTime > settings.Window
			or now - lastBounce < settings.Cooldown
		then
			return
		end
		local parts = MoveState.parts()
		if not parts or MoveState.busy or MoveState.isGrounded(parts.humanoid) then
			return
		end
		-- The jump that just launched you off a mantle isn't a bounce off that wall.
		if now - MoveState.launchTime < settings.Cooldown then
			return
		end
		local root = parts.root
		local normal = wallNormal :: Vector3
		local velocity = MoveState.flat(root.AssemblyLinearVelocity)
		local along = velocity - normal * velocity:Dot(normal)
		local out = normal * settings.OutSpeed + along * settings.KeepAlong

		root.AssemblyLinearVelocity = Vector3.new(out.X, settings.UpSpeed, out.Z)
		MoveState.airVelocity = out -- air strafing carries on from the bounce speed
		lastBounce = now
		wallNormal = nil

		-- Where the wall is relative to your body decides which limbs touch it.
		local toWall = root.CFrame:VectorToObjectSpace(-normal)
		local side = if math.abs(toWall.X) > math.abs(toWall.Z)
			then (if toWall.X < 0 then "Left" else "Right")
			elseif toWall.Z < 0 then "Front"
			else "Back"
		MoveState.bounceTime = now
		MoveState.bounceHand = if side == "Front"
			then "Both"
			elseif side == "Back" then "None"
			else side
		-- The camera rolls away from the wall.
		local wallOnLeft = workspace.CurrentCamera.CFrame.RightVector:Dot(normal) > 0
		CameraKick.kick(
			if wallOnLeft then -settings.KickRoll else settings.KickRoll,
			settings.KickPitch,
			settings.KickTime
		)

		local hum = parts.humanoid
		if trackHumanoid ~= hum then
			table.clear(tracks)
			trackHumanoid = hum
		end
		local track = tracks[side]
		if not track then
			track = AnimationBuilder.load(hum, getAnimation(side))
			tracks[side] = track
		end
		local active = track :: AnimationTrack
		active:Play(0.04)
		task.delay(settings.ContactTime + settings.HoldTime, function()
			active:Stop(settings.FadeTime)
		end)

		playSound(root, settings.HitSound, 1.15)
		playSound(root, settings.PushSound, 1.05)
	end)
end

return WallBounce
