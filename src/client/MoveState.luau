--!strict
-- Shared by the movement moves on this client: only one move (slide, vault, mantle) runs at a
-- time, and a helper that takes over the character's velocity during a move.
local MoveState = {
	busy = nil :: string?, -- name of the move in progress, or nil
}

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
