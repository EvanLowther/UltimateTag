--!strict
-- The train on a map that has one (a TrainLine module: the Metro). When such a map loads this
-- starts its timetable: the map's TrainEpoch (server time it starts) and TrainSeed (its random
-- waits), which every client reads to run the same train (client/Trains, shared/TrainLine).
-- Then every frame:
--   - whoever is in a car while the train is stopped (and anyone who squeezed in as it set off)
--     is aboard: riding, so the train never hits them, however they move about (slides and
--     crouches included) and however far behind their position reaches the server at speed;
--   - anyone else in the train's way while it's moving (anywhere from the bottom of the pit to
--     its roof: on the tracks, jumping in the pit, in front of the nose) is killed (a death on
--     the map: during a round on a FallEliminates map that puts you out of the game; MapRespawn);
--     how high and low that reaches comes with the map (its TrainLine: roofHeight, pitDepth,
--     aboardHeight), so it scales with it;
--   - when the exit stop's doors have shut, anyone still aboard is put on the platform outside
--     the nearest door (client/Trains pushes riders out first; this makes sure nobody rides round
--     again).
-- The train's parts never move on the server: only the timetable runs here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local TrainLine = require(Shared.TrainLine)

local Trains = {}

type Running = {
	map: Model,
	timetable: TrainLine.Timetable,
	phase: string,
	aboard: { [Model]: boolean }, -- characters riding (a new character never is)
}

local running: Running? = nil

local function begin(map: Instance)
	if map.Name ~= "ActiveMap" or not map:IsA("Model") then
		return
	end
	local module = map:FindFirstChild("TrainLine")
	if not module or not module:IsA("ModuleScript") then
		return
	end
	local spec = require(module) :: any
	local epoch = workspace:GetServerTimeNow() + Config.Trains.StartDelay
	local seed = math.random(1, 2 ^ 20)
	map:SetAttribute("TrainSeed", seed)
	map:SetAttribute("TrainEpoch", epoch)
	running = {
		map = map,
		timetable = TrainLine.timetable(spec, seed, epoch),
		phase = "",
		aboard = {},
	}
end

-- Puts a rider still aboard at the exit stop on the platform outside the nearest door.
local function putOff(spec: any, frames: { TrainLine.Frame }, character: Model, u: number)
	local door = TrainLine.nearestDoor(spec, u)
	local x, z = TrainLine.trainPoint(spec, frames, door + spec.doorAim, spec.pushOut)
	local frame = frames[1]
	-- Face out of the train (its left).
	local out = Vector3.new(math.sin(frame.h), 0, -math.cos(frame.h))
	local at = Vector3.new(x, spec.floorY + 3, z)
	character:PivotTo(CFrame.lookAt(at, at + out))
end

local function step()
	local train = running
	if not train then
		return
	end
	if not train.map.Parent then
		running = nil
		return
	end
	local C = Config.Trains
	local timetable = train.timetable
	local spec = timetable.spec
	local state = timetable:at(workspace:GetServerTimeNow())
	local name = state.phase.name
	local leaving = name == "leave" and train.phase ~= "leave"
	train.phase = name
	local moving = state.speed > C.MovingSpeed
	-- Just setting off from the boarding side: anyone in a car by now still counts as aboard
	-- (their position reaches the server a moment late).
	local boarding = name == "depart" or (name == "ride" and state.into < C.BoardGrace)
	local frames = TrainLine.frames(spec, state.s)
	local aboard = train.aboard
	for character in aboard do
		if not character.Parent then
			aboard[character] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local p = root.Position
		local height = p.Y - spec.floorY
		local inside, u = TrainLine.locate(spec, frames, p.X, p.Z, 0)
		local onFloor = inside ~= nil and height > C.FloorHeight and height < spec.aboardHeight
		if leaving and onFloor then
			-- Doors shut at the exit stop: nobody rides round again.
			putOff(spec, frames, character, u)
			aboard[character] = nil
		elseif not moving or boarding then
			if onFloor then
				aboard[character] = true
			elseif not moving then
				aboard[character] = nil
			end
		end
		if
			moving
			and not aboard[character]
			and height < spec.roofHeight
			and height > -spec.pitDepth
		then
			if TrainLine.locate(spec, frames, p.X, p.Z, C.KillMargin, C.NoseReach) then
				character:SetAttribute("HitByTrain", true)
				humanoid.Health = 0
			end
		end
	end
end

function Trains.start()
	workspace.ChildAdded:Connect(begin)
	local current = workspace:FindFirstChild("ActiveMap")
	if current then
		begin(current)
	end
	RunService.Heartbeat:Connect(step)
end

return Trains
