--!strict
-- The train on a map that has one (a TrainLine module: the Metro), run on every client from the
-- map's TrainEpoch and TrainSeed and the server clock (shared/TrainLine), so everyone sees the
-- same train. Every frame, before physics:
--   - moves the train's parts: each car (TrainCar), its sliding doors (TrainDoor: how far the
--     panel slides shut) and the bending gangway slices between cars (TrainGang, TrainGangT);
--   - carries you while you're aboard (you move and turn with your car, jumping included);
--   - at the exit stop, pushes you out: you walk to the nearest door and onto the platform,
--     with your controls off for the moment that takes (the server puts anyone still aboard
--     out when the doors shut);
--   - makes the exit stop's doorways (TrainFx "Gate") solid for you unless you're inside, so
--     nobody gets on there;
--   - flashes the platform edge lights (TrainWarn "A" or "B") before the train comes in, lights
--     the exit arrows (TrainFx "Push") during the push, and runs the departure boards.
-- The server (server/Trains) starts the timetable and decides who the train hits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local TrainLine = require(Shared.TrainLine)
local MoveState = require(script.Parent.MoveState)

local Trains = {}

local PUSH = "TrainPush"

type Mover = {
	part: BasePart,
	base: CFrame,
	car: number,
	door: number?,
	gang: number?,
	gangT: number,
}
type Line = {
	map: Model,
	spec: any,
	timetable: TrainLine.Timetable,
	movers: { Mover },
	parts: { BasePart },
	cframes: { CFrame },
	restInv: { CFrame },
	gangRestInv: { [string]: CFrame },
	restForward: Vector3,
	warnA: { BasePart },
	warnB: { BasePart },
	arrows: { BasePart },
	gates: { BasePart },
	boards: { TextLabel },
	boardAt: number,
	lastFrames: { TrainLine.Frame }?,
	shown: { [string]: any }, -- what the lights, arrows and gates were last set to
}

local line: Line? = nil
local pushing = false
local controlsOff = false

local function controls(): any
	local ok, module = pcall(function()
		return require(
			Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript
		) :: any
	end)
	if ok and module then
		return module:GetControls()
	end
	return nil
end

local function setControls(on: boolean)
	if controlsOff == not on then
		return
	end
	controlsOff = not on
	local playerControls = controls()
	if playerControls then
		if on then
			playerControls:Enable()
		else
			playerControls:Disable()
		end
	end
end

local function stopPushing()
	if not pushing then
		return
	end
	pushing = false
	setControls(true)
	if MoveState.busy == PUSH then
		MoveState.busy = nil
	end
	local parts = MoveState.parts()
	if parts then
		parts.humanoid:Move(Vector3.zero, false)
	end
end

-- A departure board's text, on both of its big faces.
local function makeBoard(part: BasePart, into: { TextLabel })
	local size = part.Size
	local faces = if size.X <= size.Z
		then { Enum.NormalId.Left, Enum.NormalId.Right }
		else { Enum.NormalId.Front, Enum.NormalId.Back }
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.94, 0.8)
		label.Position = UDim2.fromScale(0.03, 0.1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Arcade
		label.TextScaled = true
		label.TextColor3 = Config.Trains.BoardColor
		label.Text = ""
		label.Parent = gui
		gui.Parent = part
		table.insert(into, label)
	end
end

local function setup(map: Model)
	local module = map:WaitForChild("TrainLine", 10)
	if not module or not module:IsA("ModuleScript") or not map.Parent then
		return
	end
	local deadline = os.clock() + 10
	while
		(map:GetAttribute("TrainEpoch") == nil or map:GetAttribute("TrainSeed") == nil)
		and os.clock() < deadline
	do
		task.wait(0.1)
	end
	local epoch, seed = map:GetAttribute("TrainEpoch"), map:GetAttribute("TrainSeed")
	if type(epoch) ~= "number" or type(seed) ~= "number" or not map.Parent then
		return
	end
	local spec = require(module) :: any
	local rest = TrainLine.frames(spec, spec.restNose)
	local restInv = {}
	for c, frame in rest do
		restInv[c] = TrainLine.frameCFrame(frame):Inverse()
	end
	local new: Line = {
		map = map,
		spec = spec,
		timetable = TrainLine.timetable(spec, seed, epoch),
		movers = {},
		parts = {},
		cframes = {},
		restInv = restInv,
		gangRestInv = {},
		restForward = Vector3.new(math.cos(rest[1].h), 0, math.sin(rest[1].h)),
		warnA = {},
		warnB = {},
		arrows = {},
		gates = {},
		boards = {},
		boardAt = 0,
		lastFrames = nil,
		shown = {},
	}
	for _, item in map:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local car, gang = item:GetAttribute("TrainCar"), item:GetAttribute("TrainGang")
		if type(car) == "number" or type(gang) == "number" then
			local door = item:GetAttribute("TrainDoor")
			local gangT = item:GetAttribute("TrainGangT")
			table.insert(new.movers, {
				part = item,
				base = item.CFrame,
				car = if type(car) == "number" then car else 1,
				door = if type(door) == "number" then door else nil,
				gang = if type(gang) == "number" then gang else nil,
				gangT = if type(gangT) == "number" then gangT else 0.5,
			})
			table.insert(new.parts, item)
			table.insert(new.cframes, item.CFrame)
		end
		local warn, fx = item:GetAttribute("TrainWarn"), item:GetAttribute("TrainFx")
		if warn == "A" then
			table.insert(new.warnA, item)
		elseif warn == "B" then
			table.insert(new.warnB, item)
		end
		if fx == "Push" then
			table.insert(new.arrows, item)
		elseif fx == "Gate" then
			table.insert(new.gates, item)
		end
		if item.Name == "DepartureBoard" then
			makeBoard(item, new.boards)
		end
	end
	line = new
end

-- The gangway slice's change from where it was built.
local function gangDelta(l: Line, frames: { TrainLine.Frame }, g: number, t: number): CFrame
	local key = g .. "|" .. t
	local restInv = l.gangRestInv[key]
	if not restInv then
		local rest = TrainLine.frames(l.spec, l.spec.restNose)
		restInv = TrainLine.frameCFrame(TrainLine.gangSlice(l.spec, rest[g], rest[g + 1], t))
			:Inverse()
		l.gangRestInv[key] = restInv
	end
	return TrainLine.frameCFrame(TrainLine.gangSlice(l.spec, frames[g], frames[g + 1], t)) * restInv
end

-- Sets a group of parts' look only when it changes.
local function show(l: Line, key: string, value: any, apply: () -> ())
	if l.shown[key] ~= value then
		l.shown[key] = value
		apply()
	end
end

local function step()
	local l = line
	if not l then
		return
	end
	if not l.map.Parent then
		line = nil
		stopPushing()
		return
	end
	local C = Config.Trains
	local spec = l.spec
	local state = l.timetable:at(workspace:GetServerTimeNow())
	local frames = TrainLine.frames(spec, state.s)

	-- Aboard? Carried from where your car was last frame to where it is now.
	local parts = MoveState.parts()
	local aboard = false
	local u, w = 0, 0
	if parts and l.lastFrames then
		local p = parts.root.Position
		local height = p.Y - spec.floorY
		if height > -1 and height < C.AboardHeight then
			local car
			car, u, w = TrainLine.locate(spec, l.lastFrames, p.X, p.Z, 0)
			if car then
				aboard = true
				local before = TrainLine.frameCFrame(l.lastFrames[car])
				local after = TrainLine.frameCFrame(frames[car])
				parts.root.CFrame = (after * before:Inverse()) * parts.root.CFrame
			end
		end
	end
	l.lastFrames = frames

	-- The train's parts.
	local deltas = {}
	for c, frame in frames do
		deltas[c] = TrainLine.frameCFrame(frame) * l.restInv[c]
	end
	local shut = state.open - 1
	local gangs: { [string]: CFrame } = {}
	for i, mover in l.movers do
		local cframe
		if mover.gang then
			local key = mover.gang .. "|" .. mover.gangT
			local delta = gangs[key]
			if not delta then
				delta = gangDelta(l, frames, mover.gang, mover.gangT)
				gangs[key] = delta
			end
			cframe = delta * mover.base
		elseif mover.door then
			cframe = deltas[mover.car]
				* (CFrame.new(l.restForward * (shut * mover.door)) * mover.base)
		else
			cframe = deltas[mover.car] * mover.base
		end
		l.cframes[i] = cframe
	end
	workspace:BulkMoveTo(l.parts, l.cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- The exit push: along the aisle to the nearest door, then out onto the platform.
	local exiting = state.push or state.phase.name == "exitClose"
	if parts and exiting and (aboard or pushing) then
		local p = parts.root.Position
		local car
		car, u, w = TrainLine.locate(spec, frames, p.X, p.Z, C.PushOut)
		if car and w < C.PushOut - 1.5 and (state.push or pushing) then
			if not pushing then
				pushing = true
				setControls(false)
			end
			if MoveState.busy == nil then
				MoveState.busy = PUSH
			end
			local door = TrainLine.nearestDoor(spec, u) + 0.9
			local targetW = if math.abs(u - door) > C.PushTurn and w < spec.width / 2 - 1.5
				then w
				else C.PushOut
			local x, z = TrainLine.trainPoint(spec, frames, door, targetW)
			local to = Vector3.new(x - p.X, 0, z - p.Z)
			parts.humanoid:Move(if to.Magnitude > 0.05 then to.Unit else Vector3.zero, false)
		else
			stopPushing()
		end
	elseif pushing then
		stopPushing()
	end

	-- No getting on at the exit stop: its doorways are solid unless you're inside.
	show(
		l,
		"gate",
		(if state.gate then "on" else "off") .. (if aboard then "+in" else ""),
		function()
			for _, part in l.gates do
				part.Transparency = if state.gate then C.GateTransparency else 1
				part.CanCollide = state.gate and not aboard
			end
		end
	)
	-- Edge lights flash before the train comes in; the exit arrows flash during the push.
	local flash = math.sin(os.clock() * math.pi * 5) > -0.2
	show(l, "warnA", state.warnA and flash, function()
		for _, part in l.warnA do
			part.Color = if state.warnA and flash then C.WarnColor else C.WarnDim
		end
	end)
	show(l, "warnB", state.warnB and flash, function()
		for _, part in l.warnB do
			part.Color = if state.warnB and flash then C.WarnColor else C.WarnDim
		end
	end)
	show(l, "push", state.push and flash, function()
		for _, part in l.arrows do
			part.Color = if state.push and flash then C.ArrowColor else C.ArrowDim
		end
	end)
	if os.clock() >= l.boardAt then
		l.boardAt = os.clock() + C.BoardRefresh
		local text = TrainLine.boardText(l.timetable, state)
		for _, label in l.boards do
			label.Text = text
		end
	end
end

function Trains.start()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" and child:IsA("Model") then
			task.spawn(setup, child)
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if line and child == line.map then
			line = nil
			stopPushing()
		end
	end)
	local current = workspace:FindFirstChild("ActiveMap")
	if current and current:IsA("Model") then
		task.spawn(setup, current)
	end
	RunService.PreSimulation:Connect(step)
end

return Trains
