--!strict
-- Press Config.Slide.Key while sprinting on the ground to slide. You keep your momentum, then
-- it fades to walk speed. You can't stand up under a low ceiling, and jumping out keeps speed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sprint = require(script.Parent.Sprint)

local Slide = {}

function Slide.start()
	local player = Players.LocalPlayer
	local settings = Config.Slide

	local sliding = false
	local keyHeld = false
	local lastEnd = -math.huge
	local finish: ((jumped: boolean) -> ())? = nil
	local isBlocked: (() -> boolean)? = nil

	local function ease(instance: Instance, goal: { [string]: any })
		local info = TweenInfo.new(settings.BlendTime, Enum.EasingStyle.Quad)
		TweenService:Create(instance, info, goal):Play()
	end

	local function begin()
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if sliding or not character or not hum or not root or hum.Health <= 0 then
			return
		end
		if not Sprint.isSprinting() or hum.FloorMaterial == Enum.Material.Air then
			return
		end
		if os.clock() - lastEnd < settings.Cooldown then
			return
		end
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		-- You have to be actually running to start a slide.
		if flat.Magnitude < hum.WalkSpeed * 0.5 then
			return
		end

		sliding = true
		local dir = flat.Unit
		local startSpeed = flat.Magnitude * settings.StartMultiplier
		local endSpeed = hum.WalkSpeed / Config.Sprint.Multiplier
		local standingHip = hum.HipHeight
		local slideHip = standingHip * settings.HipHeightFactor
		local elapsed = 0
		local airTime = 0
		local speed = startSpeed

		local attachment = Instance.new("Attachment")
		attachment.Name = "SlideAttachment"
		attachment.Parent = root
		local drive = Instance.new("LinearVelocity")
		drive.Name = "SlideDrive"
		drive.Attachment0 = attachment
		drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		drive.PrimaryTangentAxis = Vector3.xAxis
		drive.SecondaryTangentAxis = Vector3.zAxis
		drive.RelativeTo = Enum.ActuatorRelativeTo.World
		drive.MaxForce = 1e6
		drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
		drive.Parent = root

		hum.AutoRotate = false
		ease(hum, { HipHeight = slideHip, CameraOffset = Vector3.new(0, -settings.CameraDip, 0) })

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = { character }
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		-- True if standing up now would put your head inside something.
		local function blockedAbove(): boolean
			local reach = (standingHip - slideHip) + settings.HeadClearance
			return workspace:Raycast(root.Position, Vector3.new(0, reach, 0), rayParams) ~= nil
		end

		local connection: RBXScriptConnection
		local function stop(jumped: boolean)
			connection:Disconnect()
			finish = nil
			isBlocked = nil
			sliding = false
			lastEnd = os.clock()
			drive:Destroy()
			attachment:Destroy()
			if hum.Parent then
				hum.AutoRotate = true
				ease(hum, { HipHeight = standingHip, CameraOffset = Vector3.zero })
				if jumped then
					local v = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
					hum.Jump = true
				end
			end
		end
		finish = stop
		isBlocked = blockedAbove

		connection = RunService.Heartbeat:Connect(function(dt)
			if not hum.Parent or not root.Parent or hum.Health <= 0 then
				stop(false)
				return
			end
			elapsed += dt
			local alpha = math.min(elapsed / settings.Duration, 1)
			speed = endSpeed + (startSpeed - endSpeed) * (1 - alpha) ^ 2

			-- Limited steering: your input only nudges the slide direction.
			local move = hum.MoveDirection
			if move.Magnitude > 0 then
				dir = (dir + move * settings.Steer * dt).Unit
			end
			drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)

			airTime = if hum.FloorMaterial == Enum.Material.Air then airTime + dt else 0
			local v = root.AssemblyLinearVelocity
			local hitWall = elapsed > 0.15 and Vector3.new(v.X, 0, v.Z).Magnitude < speed * 0.3
			local timeUp = (alpha >= 1 or not keyHeld) and not blockedAbove()
			if airTime > 0.2 or hitWall or timeUp then
				stop(false)
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == settings.Key then
			keyHeld = true
			begin()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == settings.Key then
			keyHeld = false
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		-- Jump out of a slide, unless a ceiling is in the way.
		if sliding and finish and isBlocked and not isBlocked() then
			finish(true)
		end
	end)
end

return Slide
