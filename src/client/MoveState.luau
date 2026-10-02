--!strict
-- The one source of movement state on this client, shared by every move module:
--   busy:        the move in progress ("Slide", "Vault", "Mantle"), or nil. One at a time.
--   airVelocity: the sideways speed being carried through the air (owned by AirStrafe).
--   parts():     the local character's model, humanoid and root part, if alive.
--   isGrounded(), flat(): the standard checks, so no module re-implements them.
--   drive():     a LinearVelocity that takes over the character's velocity during a move.
-- Moves keep their own small Heartbeat that only runs while they need it (no central loop).
local Players = game:GetService("Players")

export type Parts = { character: Model, humanoid: Humanoid, root: BasePart }

local MoveState = {
	busy = nil :: string?, -- name of the move in progress, or nil
	-- Sideways velocity AirStrafe carries through the air. A move that changes your velocity
	-- mid-air (like a wall bounce) sets this so air strafing continues from the new speed.
	airVelocity = nil :: Vector3?,
}

-- The local character's parts, or nil if there's no living character.
function MoveState.parts(): Parts?
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not character
		or not humanoid
		or not root
		or not root:IsA("BasePart")
		or humanoid.Health <= 0
	then
		return nil
	end
	return { character = character, humanoid = humanoid, root = root }
end

function MoveState.isGrounded(humanoid: Humanoid): boolean
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

-- The sideways part of a vector (Y set to 0).
function MoveState.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Adds a LinearVelocity to the root part. With `flat` it only controls sideways movement and
-- leaves falling to gravity. Call the returned function to remove it.
function MoveState.drive(root: BasePart, flat: boolean): (LinearVelocity, () -> ())
	local attachment = Instance.new("Attachment")
	attachment.Name = "MoveAttachment"
	attachment.Parent = root
	local drive = Instance.new("LinearVelocity")
	drive.Name = "MoveDrive"
	drive.Attachment0 = attachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.MaxForce = 1e6
	if flat then
		drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		drive.PrimaryTangentAxis = Vector3.xAxis
		drive.SecondaryTangentAxis = Vector3.zAxis
	else
		drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	end
	drive.Parent = root
	return drive, function()
		drive:Destroy()
		attachment:Destroy()
	end
end

return MoveState
