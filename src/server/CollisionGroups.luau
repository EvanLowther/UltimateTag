--!strict
-- Sets up collision groups. Parts with the "SlideBlocker" attribute block standing players
-- but let sliding players through (the client switches its character to the sliding group).
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CollisionGroups = {}

function CollisionGroups.start()
	local blocker = Config.Slide.BlockerGroup
	local sliding = Config.Slide.SlidingGroup
	PhysicsService:RegisterCollisionGroup(blocker)
	PhysicsService:RegisterCollisionGroup(sliding)
	PhysicsService:CollisionGroupSetCollidable(blocker, sliding, false)

	-- Every SlideBlocker part, including ones in maps loaded later.
	local function consider(part: Instance)
		if part:IsA("BasePart") and part:GetAttribute("SlideBlocker") then
			part.CollisionGroup = blocker
		end
	end
	for _, part in workspace:GetDescendants() do
		consider(part)
	end
	workspace.DescendantAdded:Connect(consider)
end

return CollisionGroups
