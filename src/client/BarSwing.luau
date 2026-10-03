--!strict
-- Bar swinging, like the parkour reference. Jump up to a bar (a part with the "SwingBar"
-- attribute: a cylinder lying along its X axis) and you grab it. You then swing as a pendulum
-- under it: gravity pulls you back and forth, holding forward pumps the swing higher, and
-- pressing jump lets go with the swing's momentum (plus a little boost). The slide key drops you.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local MoveState = require(script.Parent.MoveState)

local BarSwing = {}

local ATTRIBUTE = "SwingBar"

local animation: Animation? = nil

local function getAnimation(): Animation
	if not animation then
		local pose = (Config.BarSwing.Poses :: { [string]: AnimationBuilder.Angles }).Hang
		animation = AnimationBuilder.make(
			{ { time = 0, angles = pose }, { time = 1, angles = pose } },
			true,
			true
		)
	end
	return animation :: Animation
end

-- The closest point on a bar's center line to `point` (staying a little in from the ends).
local function closestOnBar(bar: BasePart, point: Vector3): Vector3
	local axis = bar.CFrame.RightVector
	local half = math.max(bar.Size.X / 2 - 0.3, 0)
	local t = math.clamp((point - bar.Position):Dot(axis), -half, half)
	return bar.Position + axis * t
end

function BarSwing.start()
	local settings = Config.BarSwing
	local bars: { BasePart } = {}
	local lastBar: BasePart? = nil
	local lastRelease = -math.huge
	local onRelease: ((jumped: boolean) -> ())? = nil -- set while hanging on a bar
	local track: AnimationTrack? = nil
	local trackHumanoid: Humanoid? = nil

	-- Keep a list of every bar in the world, including ones added later.
	local function consider(item: Instance)
		if item:IsA("BasePart") and item:GetAttribute(ATTRIBUTE) and not table.find(bars, item) then
			table.insert(bars, item)
		end
	end
	for _, item in workspace:GetDescendants() do
		consider(item)
	end
	workspace.DescendantAdded:Connect(consider)
	for _, item in CollectionService:GetTagged(ATTRIBUTE) do
		consider(item)
	end

	local function swing(parts: MoveState.Parts, bar: BasePart, grip: Vector3)
		MoveState.busy = "BarSwing"
		local root, hum = parts.root, parts.humanoid
		local axis = bar.CFrame.RightVector
		local up = Vector3.yAxis
		local radius = settings.Radius
		local gravity = workspace.Gravity

		-- The swing plane: across the bar, the way you were moving (or looking).
		local velocity = root.AssemblyLinearVelocity
		local across = MoveState.flat(velocity - axis * velocity:Dot(axis))
		if across.Magnitude < 1 then
			local look = MoveState.flat(workspace.CurrentCamera.CFrame.LookVector)
			across = look - axis * look:Dot(axis)
		end
		if across.Magnitude < 1e-3 then
			across = axis:Cross(up)
		end
		local swingDir = across.Unit
		MoveState.faceDirection = swingDir

		-- Start where you are: angle from straight down, and your speed along the swing.
		local offset = root.Position - grip
		local angle = math.atan2(offset:Dot(swingDir), -offset.Y)
		local tangent = swingDir * math.cos(angle) + up * math.sin(angle)
		local spin = velocity:Dot(tangent) / radius -- radians per second
		local maxAngle = math.rad(settings.MaxAngle)

		local drive, release = MoveState.drive(root, false)
		if trackHumanoid ~= hum or not track then
			track = AnimationBuilder.load(hum, getAnimation())
			trackHumanoid = hum
		end
		local active = track :: AnimationTrack
		active:Play(0.1)

		local connection: RBXScriptConnection
		local function letGo(jumped: boolean)
			connection:Disconnect()
			release()
			active:Stop(0.15)
			MoveState.busy = nil
			MoveState.faceDirection = nil
			onRelease = nil
			lastBar = bar
			lastRelease = os.clock()
			local t = swingDir * math.cos(angle) + up * math.sin(angle)
			local out = t * (radius * spin)
			if jumped then
				out = out * settings.ReleaseBoost + up * settings.ReleaseUp
				MoveState.launchTime = os.clock()
			end
			root.AssemblyLinearVelocity = out
			MoveState.airVelocity = MoveState.flat(out)
		end
		onRelease = letGo

		connection = RunService.Heartbeat:Connect(function(dt)
			if not hum.Parent or hum.Health <= 0 or not bar.Parent then
				letGo(false)
				return
			end
			-- Pendulum: gravity pulls you back toward straight down.
			local accel = -(gravity / radius) * math.sin(angle)
			-- Pumping: holding forward pushes the swing along the way it's already going.
			if hum.MoveDirection:Dot(swingDir) > 0.3 then
				accel += settings.PumpAccel * (if spin >= 0 then 1 else -1)
			end
			spin += accel * dt
			spin *= 1 - settings.Damping * dt
			angle += spin * dt
			if math.abs(angle) > maxAngle then
				angle = math.clamp(angle, -maxAngle, maxAngle)
				spin = 0
			end
			-- Move the body to its place on the swing, matching the swing's speed.
			local target = grip + (swingDir * math.sin(angle) - up * math.cos(angle)) * radius
			local along = (swingDir * math.cos(angle) + up * math.sin(angle)) * (radius * spin)
			drive.VectorVelocity = along + (target - root.Position) / math.max(dt, 1 / 60) * 0.5
		end)
	end

	-- Grab a bar when your raised hands reach it.
	RunService.Heartbeat:Connect(function()
		if MoveState.busy then
			return
		end
		local parts = MoveState.parts()
		if not parts or MoveState.isGrounded(parts.humanoid) then
			return
		end
		local hands = parts.root.Position + Vector3.new(0, settings.HandHeight, 0)
		for _, bar in bars do
			if
				not bar.Parent or (bar == lastBar and os.clock() - lastRelease < settings.Cooldown)
			then
				continue
			end
			local grip = closestOnBar(bar, hands)
			if
				(hands - grip).Magnitude <= settings.GrabReach
				and grip.Y > parts.root.Position.Y
			then
				swing(parts, bar, grip)
				return
			end
		end
	end)

	-- Jump lets go with a boost; the slide key just drops you.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not onRelease then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			(onRelease :: (boolean) -> ())(true)
		elseif input.KeyCode == Config.Slide.Key then
			(onRelease :: (boolean) -> ())(false)
		end
	end)
end

return BarSwing
