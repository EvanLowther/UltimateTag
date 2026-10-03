--!strict
-- Touch a wall in the air and press jump within Config.WallBounce.Window to push off it: out
-- along the wall's normal and up, keeping some of your speed along the wall. Ledges you can
-- reach still mantle automatically; a running mantle blocks a bounce.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)

local WallBounce = {}

function WallBounce.start()
	local settings = Config.WallBounce
	local wallNormal: Vector3? = nil -- the last wall touched in the air
	local wallTime = -math.huge
	local lastBounce = -math.huge
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
	end)
end

return WallBounce
