--!strict
-- Tag Stadium, the server's side (tools/stadium_layout.py; client/StadiumWorld does each player's
-- screen). When the map loads it sets the pitch chunks' seed (ChunkSeed, shared/PitchChunks) and
-- the scoreboards' kick-off time (StadiumEpoch). While bots are playing, the chunks' solid parts
-- really move here too, so bots bump into them and ride them, and a sinking chunk pushes bots out
-- from under it. It runs the loose balls: the server owns them, running into one kicks it (harder
-- the faster you run), a fast ball knocks back whoever it hits, and a ball left off the pitch goes
-- back to its spot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Contestant = require(Shared.Contestant)
local PitchChunks = require(Shared.PitchChunks)
local Remotes = require(Shared.Remotes)
local Bots = require(script.Parent.Bots)
local MapService = require(script.Parent.MapService)

local StadiumWorld = {}

type Ball = { part: BasePart, home: Vector3, out: number, lastKick: number }

local scanned: Instance? = nil
local solids: { PitchChunks.Piece } = {}
local lastF: { [number]: number } = {}
local balls: { Ball } = {}
local lastHit: { [Instance]: number } = {}

local function knock(character: Model, push: Vector3)
	local who = Contestant.fromCharacter(character)
	if not who then
		return
	end
	if who:IsA("Player") then
		Remotes.get("TagKnockback"):FireClient(who, push)
	else
		Bots.knockback(who :: any, push)
	end
end

local function setupBall(part: BasePart)
	local home = part:GetAttribute("BallHome")
	local ball: Ball = {
		part = part,
		home = if typeof(home) == "Vector3" then home else part.Position,
		out = 0,
		lastKick = -math.huge,
	}
	-- The black patches ride on the ball.
	local model = part.Parent
	if model then
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") and item ~= part then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part
				weld.Part1 = item
				weld.Parent = item
				item.Massless = true
				item.Anchored = false
			end
		end
	end
	part.CustomPhysicalProperties = PhysicalProperties.new(0.25, 0.35, 0.55, 1, 1)
	part.Anchored = false
	part:SetNetworkOwner(nil)
	local s = Config.Stadium
	part.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character or not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		local now = os.clock()
		local toThem = (root.Position - part.Position) * Vector3.new(1, 0, 1)
		if toThem.Magnitude < 0.01 then
			return
		end
		toThem = toThem.Unit
		local closing = (part.AssemblyLinearVelocity - root.AssemblyLinearVelocity):Dot(toThem)
		if closing > s.BallHitSpeed then
			if now - (lastHit[character] or -math.huge) > s.BallHitCooldown then
				lastHit[character] = now
				knock(character, toThem * s.BallHitPush)
			end
			return
		end
		if now - ball.lastKick < s.BallKickCooldown then
			return
		end
		ball.lastKick = now
		local run = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local speed = math.clamp(run.Magnitude * s.BallKickScale, s.BallKickMin, s.BallKickMax)
		local direction = -toThem
		if run.Magnitude > 4 then
			direction = (direction + run.Unit).Unit
		end
		part.AssemblyLinearVelocity = direction * speed + Vector3.new(0, s.BallKickUp, 0)
	end)
	table.insert(balls, ball)
end

local function scan(map: Instance?)
	scanned = map
	table.clear(solids)
	table.clear(lastF)
	table.clear(balls)
	table.clear(lastHit)
	if not map or map:GetAttribute("Stadium") ~= true then
		return
	end
	map:SetAttribute("ChunkSeed", math.random(1, 2 ^ 20))
	map:SetAttribute("StadiumEpoch", workspace:GetServerTimeNow())
	for _, item in map:GetDescendants() do
		if item:IsA("BasePart") then
			if item.CanCollide and item:GetAttribute("ChunkSlot") then
				local piece = PitchChunks.piece(item)
				if piece then
					table.insert(solids, piece)
				end
			elseif item:GetAttribute("Ball") then
				setupBall(item)
			end
		end
	end
end

local function moveChunks(map: Instance, t: number)
	local seed = map:GetAttribute("ChunkSeed")
	if type(seed) ~= "number" then
		return
	end
	local up = PitchChunks.at(t, seed)
	local bots = Contestant.bots()
	for _, piece in solids do
		local f = up[piece.slot]
		local before = lastF[piece.slot]
		if before == f and #bots == 0 then
			continue
		end
		if before ~= f then
			piece.part.CFrame = PitchChunks.frame(piece, f)
		end
		-- Sinking: push bots out from under it.
		if before and f < before then
			for _, bot in bots do
				local character = Contestant.character(bot)
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and not root.Anchored then
					local out =
						PitchChunks.outFrom(piece.part, root.Position, Config.Stadium.PushOut)
					if out then
						root.CFrame = root.CFrame.Rotation + out
					end
				end
			end
		end
	end
	for slot, f in up do
		lastF[slot] = f
	end
end

local function watchBalls(dt: number)
	local s = Config.Stadium
	for _, ball in balls do
		local p = ball.part.Position
		if p.Y < -10 or math.abs(p.X) > s.BallOutX or math.abs(p.Z) > s.BallOutZ then
			ball.out += dt
		else
			ball.out = 0
		end
		if ball.out > s.BallOutTime or p.Y < -40 then
			ball.out = 0
			ball.part.AssemblyLinearVelocity = Vector3.zero
			ball.part.AssemblyAngularVelocity = Vector3.zero
			ball.part.CFrame = CFrame.new(ball.home)
		end
	end
end

function StadiumWorld.start()
	RunService.Heartbeat:Connect(function(dt: number)
		local map = MapService.active()
		if map ~= scanned then
			scan(map)
		end
		if not map or #solids == 0 and #balls == 0 then
			return
		end
		-- With no bots playing, the chunks move on players' screens only (no tug of war with the
		-- server's copy); the server catches up as soon as a bot is in.
		if #Contestant.bots() > 0 then
			moveChunks(map, workspace:GetServerTimeNow())
		else
			table.clear(lastF)
		end
		watchBalls(dt)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			lastHit[player.Character] = nil
		end
	end)
end

return StadiumWorld
