--!strict
-- The one source of movement state on this client, shared by every move module:
--   busy:        the move in progress ("Slide", "Crouch", "Vault", "Mantle", "Climb", "Cling", "Hang",
--                "WallRun", "Roll"), or nil. One at a time.
--   airVelocity: the sideways speed being carried through the air (owned by AirMomentum).
--   landVelocity / landTime: the air speed you landed with (set by AirMomentum).
--   parts():     the local character's model, humanoid and root part, if alive.
--   isGrounded(), flat(): the standard checks, so no module re-implements them.
--   headroom():  studs between the top of your head and whatever is above it (ceilings), so
--                moves that drive you upward stop instead of pushing you into the roof.
--   drive():     a LinearVelocity that takes over the character's velocity during a move.
--   launch():    throws the character up and out (vault and mantle launches).
-- Moves keep their own small Heartbeat that only runs while they need it (no central loop).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Parts = { character: Model, humanoid: Humanoid, root: BasePart }

local MoveState = {
	busy = nil :: string?, -- name of the move in progress, or nil
	-- Sideways velocity AirMomentum carries through the air. A move that changes your velocity
	-- mid-air (like a wall kick) sets this so the air carries on from the new speed.
	airVelocity = nil :: Vector3?,
	-- Your sideways velocity the moment you last landed, and when. Lets a slide right after
	-- landing keep your air speed before ground friction eats it.
	landVelocity = nil :: Vector3?,
	landTime = -math.huge,
	launchTime = -math.huge, -- when the last launch (vault or mantle) happened
	wallSide = "Left", -- during a wall run: which side of your body the wall is on
	tagTime = -math.huge, -- when you last swung to tag (the first-person arm jabs)
	-- A move can set this to point the body somewhere other than the camera (FaceCamera uses
	-- it): at the wall while climbing, along the wall while wall running. nil = face the camera.
	faceDirection = nil :: Vector3?,
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

-- Studs of free space above your head, looking up to `reach` studs (math.huge if clear).
-- Only solid parts count (CanCollide), so decoration doesn't stop you.
function MoveState.headroom(parts: Parts, reach: number): number
	local head = Config.Slide.HeadClearance -- body center to the top of the head
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { parts.character }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(parts.root.Position, Vector3.new(0, head + reach, 0), params)
	return if hit then math.max(hit.Distance - head, 0) else math.huge
end

-- Throws the character along the flat direction `dir` at `forward` studs/s and upward at `up`
-- studs/s. Air strafing carries the sideways speed from there. Used by vault and mantle.
function MoveState.launch(root: BasePart, dir: Vector3, forward: number, up: number)
	local out = dir * forward
	root.AssemblyLinearVelocity = Vector3.new(out.X, up, out.Z)
	MoveState.airVelocity = out
	MoveState.launchTime = os.clock()
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
