--!strict
-- Ziplines (the Desert Mine). A grab point is a map part with a ProximityPrompt and ZipFrom, ZipTo
-- (Vector3, the two ends of the cable) and ZipSag (studs the middle hangs down). Press E to grab:
-- you ride to the far end, speeding up to Config.Ziplines.Speed, and can still swing. Jump lets go
-- and keeps your speed; so does reaching the end. Riders pass through each other. You drive your
-- own body here, so the server and everyone else simply see where you are; the ZiplineRide remote
-- marks your character `Riding`, so every screen hangs you from the line with a trolley.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local MoveState = require(script.Parent.MoveState)
local Slide = require(script.Parent.Slide)

local Ziplines = {}

local hangAnimation: Animation? = nil

local function getHang(): Animation
	if not hangAnimation then
		local pose = Config.Ziplines.Pose :: AnimationBuilder.Angles
		hangAnimation = AnimationBuilder.make({
			{ time = 0, angles = pose },
			{ time = 30, angles = pose },
		})
	end
	return hangAnimation :: Animation
end

local function pointAt(from: Vector3, to: Vector3, sag: number, u: number): Vector3
	return from:Lerp(to, u) - Vector3.new(0, sag * 4 * u * (1 - u), 0)
end

local riding = false
local letGo: (() -> ())? = nil

local function ride(from: Vector3, to: Vector3, sag: number, grab: BasePart)
	local parts = MoveState.parts()
	if riding or not parts or parts.humanoid.WalkSpeed <= 0 or parts.humanoid.Health <= 0 then
		return
	end
	local busy = MoveState.busy
	if busy == "Slide" or busy == "Crouch" then
		Slide.cancel()
	elseif busy then
		return
	end
	local settings = Config.Ziplines
	local root, humanoid, character = parts.root, parts.humanoid, parts.character
	riding = true
	MoveState.busy = "Zipline"
	MoveState.airVelocity = nil
	humanoid.PlatformStand = true
	character:SetAttribute("Riding", true)
	Remotes.get("ZiplineRide"):FireServer(true)

	local u, speed, started = 0, settings.StartSpeed, os.clock()
	local tangent = (to - from).Unit
	local step: RBXScriptConnection
	local function finish()
		if not riding then
			return
		end
		riding = false
		letGo = nil
		step:Disconnect()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		character:SetAttribute("Riding", nil)
		Remotes.get("ZiplineRide"):FireServer(false)
		if root.Parent then
			root.AssemblyLinearVelocity = tangent * speed
			MoveState.airVelocity = MoveState.flat(root.AssemblyLinearVelocity)
		end
		if MoveState.busy == "Zipline" then
			MoveState.busy = nil
		end
	end
	letGo = function()
		if os.clock() - started >= settings.DropDelay then
			finish()
		end
	end
	step = RunService.PreSimulation:Connect(function(dt: number)
		if not root.Parent or humanoid.Health <= 0 or not grab.Parent then
			finish()
			return
		end
		speed = math.min(speed + settings.Accel * dt, settings.Speed)
		local ahead = pointAt(from, to, sag, math.min(u + 0.01, 1))
		local here = pointAt(from, to, sag, u)
		local span = ahead - here
		if span.Magnitude > 1e-3 then
			tangent = span.Unit
			u += speed * dt * 0.01 / span.Magnitude
		end
		if u >= 1 then
			finish()
			return
		end
		local at = pointAt(from, to, sag, u) - Vector3.new(0, settings.Hang, 0)
		local facing = MoveState.flat(tangent)
		root.CFrame = CFrame.lookAt(
			at,
			at + (if facing.Magnitude > 0.05 then facing.Unit else root.CFrame.LookVector)
		)
		root.AssemblyLinearVelocity = tangent * speed
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

-- Hang pose and trolley on any rider, on this screen.
local function watchCharacter(character: Model)
	local track: AnimationTrack? = nil
	local trolley: BasePart? = nil
	local follow: RBXScriptConnection? = nil
	local function update()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local on = character:GetAttribute("Riding") == true
		if on and humanoid then
			if not track then
				track = AnimationBuilder.load(humanoid, getHang())
			end
			local active = track :: AnimationTrack
			if not active.IsPlaying then
				active:Play(0.1)
			end
			if not trolley then
				local settings = Config.Ziplines
				local part = Instance.new("Part")
				part.Name = "ZipTrolley"
				part.Size = settings.TrolleySize
				part.Color = settings.TrolleyColor
				part.Material = Enum.Material.Metal
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Parent = character
				trolley = part
				follow = RunService.RenderStepped:Connect(function()
					local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						part.CFrame = root.CFrame + Vector3.new(0, settings.Hang, 0)
					end
				end)
			end
		else
			if track and track.IsPlaying then
				track:Stop(0.15)
			end
			if follow then
				follow:Disconnect()
				follow = nil
			end
			if trolley then
				trolley:Destroy()
				trolley = nil
			end
		end
	end
	character:GetAttributeChangedSignal("Riding"):Connect(update)
	update()
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

function Ziplines.start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	UserInputService.JumpRequest:Connect(function()
		if letGo then
			letGo()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local grab = prompt.Parent
		if not grab or not grab:IsA("BasePart") then
			return
		end
		local from, to = grab:GetAttribute("ZipFrom"), grab:GetAttribute("ZipTo")
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
			ride(from, to, (grab:GetAttribute("ZipSag") or 0) :: number, grab)
		end
	end)
end

return Ziplines
