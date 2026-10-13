--!strict
-- Ladders. Roblox characters climb TrussParts by themselves: walk into one and you go up it,
-- jump to let go. Maps build their ladders from invisible trusses with rails and rungs drawn in
-- front (tools/maplib.py `ladder`). While you're climbing, the climb holds MoveState.busy, so air
-- momentum, wall runs, slides and launch pads leave you alone until you step off or jump off.
local RunService = game:GetService("RunService")

local MoveState = require(script.Parent.MoveState)

local Ladders = {}

local CLIMB = "Climb"

function Ladders.start()
	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		local climbing = parts ~= nil
			and parts.humanoid:GetState() == Enum.HumanoidStateType.Climbing
		if climbing and MoveState.busy == nil then
			MoveState.busy = CLIMB
		elseif not climbing and MoveState.busy == CLIMB then
			MoveState.busy = nil
		end
	end)
end

return Ladders
