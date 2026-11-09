--!strict
-- The Arctic Icebreaker, the server's side (shared/ShipRoll; client/ShipWorld does each player's
-- screen): the loose containers' solid parts really move here, so bots bump into them, and bots
-- are pushed downhill and knocked back by a sliding container like players are.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Contestant = require(Shared.Contestant)
local ShipRoll = require(Shared.ShipRoll)
local Bots = require(script.Parent.Bots)
local MapService = require(script.Parent.MapService)

local ShipWorld = {}

type Solid = { part: BasePart, base: CFrame, builtX: number, index: number }

local solids: { Solid } = {}
local scanned: Instance? = nil
local lastHit: { [Instance]: number } = {}

local function scan(map: Instance?)
	table.clear(solids)
	scanned = map
	if not map or map:GetAttribute("ShipRoll") ~= true then
		return
	end
	for _, child in map:GetChildren() do
		local n = string.match(child.Name, "^Loose(%d+)$")
		if n then
			for _, part in child:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					table.insert(solids, {
						part = part,
						base = part.CFrame,
						builtX = part.Position.X,
						index = tonumber(n) :: number,
					})
				end
			end
		end
	end
end

function ShipWorld.start()
	RunService.Heartbeat:Connect(function(dt: number)
		local map = MapService.active()
		if map ~= scanned then
			scan(map)
		end
		if #solids == 0 then
			return
		end
		local s = Config.ShipRoll
		local t = workspace:GetServerTimeNow()
		for _, solid in solids do
			local x = ShipRoll.container(t, solid.index)
			solid.part.CFrame = solid.base + Vector3.new(x - solid.builtX, 0, 0)
		end
		local roll = ShipRoll.at(t)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		for _, bot in Contestant.bots() do
			local character = Contestant.character(bot)
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or root.Anchored or not character then
				continue
			end
			if math.abs(roll) > math.rad(s.PushFrom) then
				local dx = -math.sin(roll) / math.sin(math.rad(s.MaxRoll)) * s.PushSpeed * dt
				params.FilterDescendantsInstances = { character }
				local direction = Vector3.new(if dx > 0 then 1 else -1, 0, 0)
				local probe = direction * (math.abs(dx) + s.PushClear)
				if
					not workspace:Raycast(root.Position + Vector3.new(0, -2.4, 0), probe, params)
				then
					root.CFrame += Vector3.new(dx, 0, 0)
				end
			end
			for _, solid in solids do
				local _, speed = ShipRoll.container(t, solid.index)
				if
					math.abs(speed) > s.HitSpeed
					and os.clock() - (lastHit[bot] or -math.huge) > s.HitCooldown
				then
					local p, c, half = root.Position, solid.part.Position, solid.part.Size / 2
					if
						math.abs(p.X - c.X) < half.X + 1.5
						and math.abs(p.Z - c.Z) < half.Z + 1.2
						and math.abs(p.Y - c.Y) < half.Y + 2
					then
						lastHit[bot] = os.clock()
						Bots.knockback(
							bot :: any,
							Vector3.new((if speed > 0 then 1 else -1) * s.HitPush, 0, 0)
						)
					end
				end
			end
		end
	end)
end

return ShipWorld
