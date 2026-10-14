--!strict
-- Coyote time: a jump still works for a moment (Config.Jump.CoyoteTime) after you run, walk or
-- slide off an edge, so a jump pressed a beat late at a roof edge or a gap still goes. Once per
-- time in the air: not after you've already jumped, and not after a move took over in the air
-- (a wall run, a launch pad, a ladder). Frozen players (jump height 0) can't.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local Slide = require(script.Parent.Slide)

local CoyoteJump = {}

-- Moves that leave you able to coyote-jump when they carry you off an edge.
local CARRIES = { Slide = true, Crouch = true }

function CoyoteJump.start()
	local lastGround = -math.huge
	local spent = false -- jumped (or a move took over) since you last stood on something
	local watched: Humanoid? = nil
	local stateConnection: RBXScriptConnection? = nil

	-- A normal jump uses up the coyote jump.
	local function watch(hum: Humanoid)
		if watched == hum then
			return
		end
		watched = hum
		if stateConnection then
			stateConnection:Disconnect()
		end
		stateConnection = hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				spent = true
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		if not parts then
			return
		end
		watch(parts.humanoid)
		local busy = MoveState.busy
		-- (The floor can still read as solid on the frame you jump: the state says you've left.)
		local state = parts.humanoid:GetState()
		local airborne = state == Enum.HumanoidStateType.Jumping
			or state == Enum.HumanoidStateType.Freefall
		if MoveState.isGrounded(parts.humanoid) and not airborne and busy ~= "WallRun" then
			lastGround = os.clock()
			spent = false
		elseif busy and not CARRIES[busy] then
			spent = true
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		local parts = MoveState.parts()
		if not parts or spent then
			return
		end
		local hum, root = parts.humanoid, parts.root
		if MoveState.isGrounded(hum) or os.clock() - lastGround > Config.Jump.CoyoteTime then
			return -- on the ground Roblox jumps by itself; too late in the air
		end
		local busy = MoveState.busy
		if busy and not CARRIES[busy] then
			return
		end
		local up = if hum.UseJumpPower
			then hum.JumpPower
			else math.sqrt(2 * workspace.Gravity * hum.JumpHeight)
		if up <= 0 or not hum:GetStateEnabled(Enum.HumanoidStateType.Jumping) and not busy then
			return -- frozen
		end
		spent = true
		if busy == "Slide" and Slide.jump() then
			return -- a slide jump: its speed, and higher the faster you were going
		end
		if busy then
			Slide.cancel() -- off the edge mid-crouch: end it
		end
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, up, v.Z)
	end)
end

return CoyoteJump
