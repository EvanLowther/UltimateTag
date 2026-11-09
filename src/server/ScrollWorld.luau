--!strict
-- Canyon Express, the bots' side: the obstacles are moved on each screen (client/ScrollWorld), so
-- here the same timetable (shared/ScrollLine) knocks back any bot whose body is in one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Contestant = require(Shared.Contestant)
local ScrollLine = require(Shared.ScrollLine)
local Bots = require(script.Parent.Bots)
local MapService = require(script.Parent.MapService)

local ScrollWorld = {}

type Box = { center: Vector3, half: Vector3 }

local boxes: { [string]: { [number]: { Box } } } = {}
local built: { [string]: { [number]: number } } = {}
local scanned: Instance? = nil
local lastHit: { [Instance]: number } = {}

local function scan(map: Instance?)
	table.clear(boxes)
	table.clear(built)
	scanned = map
	if not map then
		return
	end
	local step = Config.ScrollWorld.ParkStep
	for _, child in map:GetChildren() do
		local kind, pool = string.match(child.Name, "^Obstacle_(%a+)_(%d+)$")
		if kind and pool then
			local n = tonumber(pool) :: number
			local list: { Box } = {}
			local x = 0
			for _, item in child:GetDescendants() do
				if item:IsA("BasePart") then
					x = math.round(item.Position.X / step) * step
					if item:GetAttribute("ObstacleHit") == true then
						table.insert(list, { center = item.Position, half = item.Size / 2 })
					end
				end
			end
			boxes[kind] = boxes[kind] or {}
			boxes[kind][n] = list
			built[kind] = built[kind] or {}
			built[kind][n] = x
		end
	end
end

function ScrollWorld.start()
	RunService.Heartbeat:Connect(function()
		local map = MapService.active()
		if map ~= scanned then
			scan(if map and map:GetAttribute("ScrollWorld") == true then map else nil)
			scanned = map
		end
		if not map or next(boxes) == nil then
			return
		end
		local s = Config.ScrollWorld
		local t = workspace:GetServerTimeNow()
		local active = ScrollLine.obstacles(t)
		local driftZ = ScrollLine.trainB(t).Z
		local now = os.clock()
		for _, bot in Contestant.bots() do
			local character = Contestant.character(bot)
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or now - (lastHit[bot] or -math.huge) < s.HitCooldown then
				continue
			end
			local p = root.Position
			for _, obstacle in active do
				local list = boxes[obstacle.kind] and boxes[obstacle.kind][obstacle.pool]
				if not list then
					continue
				end
				local dx = obstacle.x - built[obstacle.kind][obstacle.pool]
				local dz = if string.sub(obstacle.kind, -1) == "B" then driftZ else 0
				for _, box in list do
					if
						math.abs(p.X - (box.center.X + dx)) <= box.half.X + s.HitReach
						and math.abs(p.Z - (box.center.Z + dz)) <= box.half.Z + 1
						and p.Y + 2.6 > box.center.Y - box.half.Y
						and p.Y - 3 < box.center.Y + box.half.Y
					then
						lastHit[bot] = now
						Bots.knockback(bot :: any, Vector3.new(-s.HitPush, 0, 0))
						break
					end
				end
			end
		end
	end)
end

return ScrollWorld
