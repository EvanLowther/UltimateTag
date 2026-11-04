--!strict
-- What the bots (server/Bots) do, on the server. Every frame each bot steers toward where it's
-- going (a path's next point, or straight at a spot it can see), sprinting like a player; every
-- Config.Bots.Think seconds it decides where that is:
--   It:      chases the nearest Runner no other It is nearer to (ShareDistance: two Its don't
--            chase one Runner), real players first (PreferPlayers studs nearer; a bot Runner
--            within CloseBot it hasn't tagged yet this round counts the same), aiming a little ahead of where they're running (Lead),
--            straight at them when it can see them on the same level, by a path otherwise
--            (to the floor right under them when they're on another level, so it goes up the
--            ladder, ramp or stairs that leads there however far round that is; a Runner it
--            finds no way to is left be for NoPathTime). Once a Runner is in reach it swings a beat
--            later (Reaction); now and then a swing is mistimed (SwingMiss). It slides into a
--            straight chase now and then. A bot that was just tagged can't swing for
--            TaggedPause (it chases meanwhile).
--   Runner:  roams while every It is far (CalmDistance). Once one comes close (FleeDistance) it
--            runs for the open spot furthest from every It (launch pads count, and throw it
--            clear); spots near other Runners score lower (SpreadDistance), so they spread out
--            over the map, and one that has stayed in one area (CampRadius) for CampTime moves
--            on somewhere else. And when an It closes in (DodgeDistance) it dodges: a sidestep, a jump or a
--            slide.
--   Lobby, countdown, results: wanders round where it is at a walk. The intro and the win
--            screen: stands still.
-- Bots react a beat late and sometimes miss, so players can beat them. They sprint, jump, slide
-- (the clients pose it, client/BotPoses), climb ladders, take stairs and launch pads, get pushed
-- by hits (Bots.knockback) and get unstuck (a jump, then another way). On maps that can kill
-- (a KillHeight, a train) they never step off a drop deeper than DangerDrop, so they don't walk
-- off a roof or into the train's pit. Wall runs are beyond them.
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Contestant = require(Shared.Contestant)
local GameState = require(Shared.GameState)
local Bots = require(script.Parent.Bots)
local MapService = require(script.Parent.MapService)
local Participants = require(script.Parent.Participants)
local Roles = require(script.Parent.Roles)
local TagService = require(script.Parent.TagService)

local BotBrain = {}

local UP = Vector3.yAxis
local GAME_PHASES = { Intro = true, Playing = true, Results = true }

type Brain = {
	bot: ObjectValue,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	tracks: { [string]: AnimationTrack },
	playing: string?,
	standingHip: number,
	-- Where it's going.
	mode: string, -- "Idle", "Roam", "Flee", "Chase"
	pendingMode: string?, -- a change it hasn't reacted to yet
	pendingAt: number,
	goal: Vector3?, -- the spot it's heading for
	direct: boolean, -- straight there (it can see it) instead of by the path
	waypoints: { PathWaypoint }?,
	waypoint: number,
	pathFor: Vector3?, -- the goal the path was made for
	pathAt: number, -- when it was made
	computing: boolean,
	lastDir: Vector3,
	sprint: boolean,
	nextThink: number,
	roamUntil: number,
	-- Chasing.
	role: string?, -- its role when it last thought (a change to It is a tag)
	pauseUntil: number, -- just tagged: can't swing until then (Config.Bots.TaggedPause)
	target: any?, -- the Runner it's after
	noPath: { [any]: number }, -- Runners it found no way to (until when it leaves them be)
	targetSince: number,
	inReachSince: number?,
	swingAt: number?,
	-- Moves.
	slideUntil: number,
	slideStart: number,
	lastSlide: number,
	dodgeDir: Vector3?,
	dodgeUntil: number,
	dodgeThreat: any?, -- the It it last decided about dodging
	flight: LinearVelocity?, -- holds a launch pad's throw across until it lands
	launchCheck: number,
	-- Not camping (a Runner): where it has been hanging about, and since when.
	campFrom: Vector3,
	campSince: number,
	-- Unsticking.
	progressAt: number,
	progressFrom: Vector3,
	stuckTries: number,
}

local brains: { [ObjectValue]: Brain } = {}
-- Who each bot has tagged this round (it prefers real players, but a bot Runner close by that
-- it hasn't tagged yet this round is fair game).
local taggedBy: { [ObjectValue]: { round: number, who: { [any]: boolean } } } = {}

local function hasTagged(bot: ObjectValue, contestant: any): boolean
	local record = taggedBy[bot]
	return record ~= nil and record.round == GameState.getRound() and record.who[contestant] == true
end

local function rememberTag(bot: ObjectValue, contestant: any)
	local round = GameState.getRound()
	local record = taggedBy[bot]
	if not record or record.round ~= round then
		record = { round = round, who = {} }
		taggedBy[bot] = record
	end
	record.who[contestant] = true
end
local random = Random.new()

local agent = {
	AgentRadius = 1.5, -- (2 was as wide as a ladder's rails: no path went up one)
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = true,
	WaypointSpacing = 4,
	Costs = { Climb = 3 },
}

local function rnd(a: number, b: number): number
	return a + random:NextNumber() * (b - a)
end

local function reaction(): number
	local range = Config.Bots.Reaction
	return rnd(range[1], range[2])
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Every character in the game, so rays look past bodies.
local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, contestant in Contestant.all() do
		local character = Contestant.character(contestant)
		if character then
			table.insert(ignore, character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return params
end

-- The floor under a spot (searching from a little above it), or nil if there's none near.
local function floorAt(point: Vector3, params: RaycastParams, depth: number?): Vector3?
	local hit = workspace:Raycast(point + UP * 6, -UP * (6 + (depth or 30)), params)
	return if hit then hit.Position else nil
end

-- Nothing solid between two spots at waist height.
local function clearLine(from: Vector3, to: Vector3, params: RaycastParams): boolean
	local a = from + UP * 0.5
	local b = to + UP * 2.5
	return workspace:Raycast(a, b - a, params) == nil
end

-- Can this map kill (a fall out of the game, a train)? Then bots keep off drops.
local function dangerous(): boolean
	local map = MapService.active()
	return map ~= nil
		and (
			map:GetAttribute("KillHeight") ~= nil
			or map:GetAttribute("FallEliminates") == true
			or map:FindFirstChild("TrainLine") ~= nil
		)
end

local function rootOf(contestant: any): BasePart?
	local character = Contestant.character(contestant)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	if character:GetAttribute("Parked") then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The others still in the game with this role (and a body on the map).
local function others(bot: ObjectValue, role: string): { { contestant: any, root: BasePart } }
	local list = {}
	for _, contestant in Participants.alive() do
		if contestant ~= bot and Roles.get(contestant) == role then
			local root = rootOf(contestant)
			if root then
				table.insert(list, { contestant = contestant, root = root })
			end
		end
	end
	return list
end

-- Launch pads on the loaded map (not pop-ups: those spring for everyone, players only).
local function launchPads(): { BasePart }
	local map = MapService.active()
	local pads = {}
	if map then
		for _, part in map:GetDescendants() do
			if
				part:IsA("BasePart")
				and typeof(part:GetAttribute("LaunchVelocity")) == "Vector3"
				and part:GetAttribute("PopUp") == nil
			then
				table.insert(pads, part)
			end
		end
	end
	return pads
end

-- Animations -------------------------------------------------------------------------------

local function play(brain: Brain, name: string, speed: number)
	local track = brain.tracks[name]
	if not track then
		local state = Bots.state(brain.bot)
		local animation = state and state.animations[name]
		local animator = brain.humanoid:FindFirstChildOfClass("Animator")
		if not animation or not animator then
			return
		end
		track = animator:LoadAnimation(animation)
		track.Looped = name ~= "jump"
		brain.tracks[name] = track
	end
	if brain.playing ~= name then
		if brain.playing and brain.tracks[brain.playing] then
			brain.tracks[brain.playing]:Stop(0.15)
		end
		track:Play(0.15)
		brain.playing = name
	end
	track:AdjustSpeed(speed)
end

local function animate(brain: Brain)
	local state = brain.humanoid:GetState()
	local speed = flat(brain.root.AssemblyLinearVelocity).Magnitude
	-- Sliding: standing still underneath, the clients pose the slide over it (client/BotPoses).
	if brain.slideUntil > os.clock() then
		state, speed = Enum.HumanoidStateType.Running, 0
	end
	if state == Enum.HumanoidStateType.Climbing then
		play(brain, "climb", math.clamp(brain.root.AssemblyLinearVelocity.Y / 8, 0.3, 1.5))
	elseif state == Enum.HumanoidStateType.Jumping then
		play(brain, "jump", 1)
	elseif state == Enum.HumanoidStateType.Freefall then
		play(brain, "fall", 1)
	elseif speed > 13 then
		play(brain, "run", math.clamp(speed / Config.RunPace.NormalSpeed, 0.6, 1.45))
	elseif speed > 0.5 then
		play(brain, "walk", math.clamp(speed / 10, 0.6, 1.3))
	else
		play(brain, "idle", 1)
	end
end

-- Moves -----------------------------------------------------------------------------------

local function setGroup(brain: Brain, group: string)
	for _, part in brain.character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

local function endSlide(brain: Brain)
	brain.slideUntil = 0
	brain.humanoid.HipHeight = brain.standingHip
	brain.character:SetAttribute("BotMove", nil)
	setGroup(brain, "Default")
end

-- A slide: a burst of speed fading back to running, low enough to pass under slide bars.
local function slide(brain: Brain)
	local now = os.clock()
	if
		now - brain.lastSlide < Config.Bots.SlideCooldown
		or brain.humanoid.FloorMaterial == Enum.Material.Air
		or flat(brain.root.AssemblyLinearVelocity).Magnitude < Config.Speed.Runner
	then
		return
	end
	brain.lastSlide = now
	brain.slideStart = now
	brain.slideUntil = now + Config.Bots.SlideTime
	brain.humanoid.HipHeight = brain.standingHip * Config.Slide.HipHeightFactor
	brain.character:SetAttribute("BotMove", "Slide")
	setGroup(brain, Config.Slide.SlidingGroup)
end

-- Holds a throw's speed across until the bot lands (the humanoid would brake it in the air).
local function hold(brain: Brain, velocity: Vector3)
	if brain.flight then
		brain.flight:Destroy()
	end
	local attachment = brain.root:FindFirstChild("BotFlight") :: Attachment?
	if not attachment then
		local made = Instance.new("Attachment")
		made.Name = "BotFlight"
		made.Parent = brain.root
		attachment = made
	end
	local drive = Instance.new("LinearVelocity")
	drive.Attachment0 = attachment
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.MaxForce = 1e6
	drive.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	drive.Parent = brain.root
	brain.flight = drive
	local started = os.clock()
	task.spawn(function()
		task.wait(0.3) -- leave the pad first
		while
			drive.Parent
			and brain.humanoid.Parent
			and brain.humanoid.FloorMaterial == Enum.Material.Air
			and os.clock() - started < 4
		do
			task.wait()
		end
		drive:Destroy()
		if brain.flight == drive then
			brain.flight = nil
		end
	end)
end

-- Standing on a launch pad: thrown like a player is (client/MapGadgets does it for them).
local function checkLaunch(brain: Brain, params: RaycastParams)
	local now = os.clock()
	if now < brain.launchCheck then
		return
	end
	brain.launchCheck = now + Config.Bots.LaunchCheck
	if brain.flight then
		return
	end
	local hit = workspace:Raycast(brain.root.Position, -UP * 5, params)
	local pad = hit and hit.Instance
	local velocity = pad and pad:GetAttribute("LaunchVelocity")
	if not pad or typeof(velocity) ~= "Vector3" or pad:GetAttribute("PopUp") ~= nil then
		return
	end
	if pad:GetAttribute("LaunchAnyDirection") == true then
		local across = flat(velocity).Magnitude
		local heading = if brain.lastDir.Magnitude > 0.1
			then brain.lastDir
			else flat(brain.root.CFrame.LookVector).Unit
		velocity = heading * across + UP * velocity.Y
	end
	if brain.slideUntil > 0 then
		endSlide(brain)
	end
	brain.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	brain.root.AssemblyLinearVelocity = velocity
	hold(brain, velocity)
	brain.waypoints = nil -- wherever it was going, it's somewhere else now
	brain.goal = nil
end

-- Paths -----------------------------------------------------------------------------------

-- Rejects paths that step off a drop on a map that can kill.
local function safePath(waypoints: { PathWaypoint }): boolean
	if not dangerous() then
		return true
	end
	local limit = Config.Bots.DangerDrop
	for i = 2, #waypoints do
		local drop = waypoints[i - 1].Position.Y - waypoints[i].Position.Y
		if drop > limit and waypoints[i].Action ~= Enum.PathWaypointAction.Custom then
			return false
		end
	end
	return true
end

-- How high the bot's middle stands over its feet (standing).
local function rootHeight(brain: Brain): number
	return brain.standingHip + brain.root.Size.Y / 2
end

-- A path from `from` to `goal` it can take (nil: none).
local function computePath(from: Vector3, goal: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath(agent)
	local ok = pcall(function()
		path:ComputeAsync(from, goal)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints >= 2 and safePath(waypoints) then
			return waypoints
		end
	end
	return nil
end

-- Spots to try when there's no path to `goal` itself: round it on the same floor (the goal can
-- sit right against a wall, a rail or a ledge's edge, where the agent doesn't fit).
local NEARBY = {
	Vector3.new(3, 0, 0),
	Vector3.new(-3, 0, 0),
	Vector3.new(0, 0, 3),
	Vector3.new(0, 0, -3),
	Vector3.new(5, 0, 5),
	Vector3.new(-5, 0, -5),
}

-- Works out a path to `goal` in the background. Another level that the path can't reach right
-- at the goal tries spots round it; a goal with no way there at all is never run at in a
-- straight line from below (that only works on its own level): a chase leaves that Runner be
-- for a while (`noPath`), anything else picks somewhere new.
local function requestPath(brain: Brain, goal: Vector3)
	if brain.computing then
		return
	end
	brain.computing = true
	local from = brain.root.Position
	local feet = from.Y - rootHeight(brain)
	local level = math.abs(goal.Y - feet) < 2.5
	local target = if brain.mode == "Chase" then brain.target else nil
	task.spawn(function()
		local waypoints = computePath(from, goal)
		if not waypoints and not level then
			local params = rayParams()
			for _, offset in NEARBY do
				local spot = floorAt(goal + offset, params, 4)
				if spot and math.abs(spot.Y - goal.Y) < 2 then
					waypoints = computePath(from, spot)
					if waypoints then
						break
					end
				end
			end
		end
		brain.computing = false
		if not brains[brain.bot] or brain.character ~= brain.bot.Value then
			return
		end
		brain.pathAt = os.clock()
		brain.pathFor = goal
		if waypoints then
			brain.waypoints = waypoints
			brain.waypoint = 2
			brain.direct = false
			if target then
				brain.noPath[target] = nil
			end
			return
		end
		brain.waypoints = nil
		if level then
			brain.direct = true -- its own level: straight at it (round small things)
		elseif target then
			brain.noPath[target] = os.clock() + Config.Bots.NoPathTime
			brain.direct = false
		else
			brain.goal = nil -- somewhere else next time
			brain.roamUntil = 0
			brain.direct = false
		end
	end)
end

-- Heads for `goal` (a spot on the floor): straight there if it's on its level and nothing is in
-- the way, otherwise by a path (made again every PathRefresh, or when the goal moved far; a goal
-- with no way there waits for the next refresh before trying again).
local function goTo(brain: Brain, goal: Vector3, params: RaycastParams)
	brain.goal = goal
	local feet = brain.root.Position.Y - rootHeight(brain)
	local level = math.abs(goal.Y - feet) < 2.5
	if level and clearLine(brain.root.Position, goal, params) then
		brain.direct = true
		brain.waypoints = nil
		return
	end
	local stale = os.clock() - brain.pathAt > Config.Bots.PathRefresh
	local moved = brain.pathFor == nil or (brain.pathFor - goal).Magnitude > 6
	-- (Mid-climb it keeps the path it's on: a path from halfway up a ladder rarely works out.)
	local climbing = brain.humanoid:GetState() == Enum.HumanoidStateType.Climbing
	if (stale or moved) and not (climbing and brain.waypoints) then
		requestPath(brain, goal)
	end
	if brain.waypoints then
		brain.direct = false
	end
end

-- Deciding ----------------------------------------------------------------------------------

-- Somewhere to run to: open floor round the bot (and launch pads) scored by how far it is from
-- every threat, avoiding heading toward one.
local function escapeSpot(
	brain: Brain,
	threats: { { contestant: any, root: BasePart } },
	params: RaycastParams,
	panicking: boolean,
	avoid: Vector3?
): Vector3?
	local position = brain.root.Position
	local settings = Config.Bots
	local mates = if Roles.get(brain.bot) == "Runner" then others(brain.bot, "Runner") else {}
	local danger = dangerous()
	local myFloor = floorAt(position, params, 8)
	local best: Vector3? = nil
	local bestScore = -math.huge
	local function score(spot: Vector3, bonus: number)
		local nearest = math.huge
		local away = flat(spot - position)
		local penalty = 0
		for _, threat in threats do
			local at = threat.root.Position
			nearest = math.min(nearest, (at - spot).Magnitude)
			local toward = flat(at - position)
			if away.Magnitude > 0.1 and toward.Magnitude > 0.1 then
				local facing = away.Unit:Dot(toward.Unit)
				if facing > 0.3 then
					penalty += 60 * facing -- running at the It
				end
			end
		end
		if #threats == 0 then
			nearest = rnd(20, 60)
		end
		-- Away from the other Runners too, so they spread over the map instead of bunching up.
		for _, mate in mates do
			local gap = (mate.root.Position - spot).Magnitude
			if gap < settings.SpreadDistance then
				penalty += (settings.SpreadDistance - gap) * settings.SpreadWeight
			end
		end
		-- Camping: somewhere else, out of the area it has been hanging about in.
		if avoid and flat(spot - avoid).Magnitude < settings.CampRadius then
			penalty += 80
		end
		local value = nearest - penalty + bonus + rnd(0, 6)
		if clearLine(position, spot, params) then
			value += 12
		end
		if value > bestScore then
			best, bestScore = spot, value
		end
	end
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2 + rnd(-0.15, 0.15)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		for _, distance in { 14, 28, 42 } do
			local spot = floorAt(position + dir * distance, params)
			if spot then
				local drop = (if myFloor then myFloor.Y else position.Y - 3) - spot.Y
				if not (danger and drop > settings.DangerDrop) and math.abs(drop) < 20 then
					score(spot, 0)
				end
			end
		end
	end
	if panicking then
		for _, pad in launchPads() do
			if (pad.Position - position).Magnitude < 40 then
				score(pad.Position + UP * (pad.Size.Y / 2), 25)
			end
		end
	end
	return best
end

-- Somewhere to wander to: a spawn point or a floor spot nearby, away from any It.
local function roamSpot(brain: Brain, params: RaycastParams, near: Vector3?): Vector3?
	local position = brain.root.Position
	local around = near or position
	local radius = if near then 24 else 40
	for _ = 1, 8 do
		local angle = rnd(0, math.pi * 2)
		local spot = floorAt(
			around + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rnd(8, radius),
			params
		)
		if spot and math.abs(spot.Y - position.Y) < 12 then
			return spot
		end
	end
	local map = MapService.active()
	if map and not near then
		local points = MapService.spawnPoints(map)
		if #points > 0 then
			return points[random:NextInteger(1, #points)].Position
		end
	end
	return nil
end

-- Somewhere across the map from `from`: a spawn point well out of the area (they're spread over
-- the map), for a Runner that has been hanging about in one place.
local function farSpot(from: Vector3): Vector3?
	local map = MapService.active()
	if not map then
		return nil
	end
	local choices = {}
	for _, point in MapService.spawnPoints(map) do
		if flat(point.Position - from).Magnitude > Config.Bots.CampRadius * 2 then
			table.insert(choices, point.Position)
		end
	end
	if #choices == 0 then
		return nil
	end
	return choices[random:NextInteger(1, #choices)]
end

-- Switches mode a reaction time after it would have.
local function want(brain: Brain, mode: string): boolean
	local now = os.clock()
	if brain.mode == mode then
		brain.pendingMode = nil
		return true
	end
	if brain.pendingMode ~= mode then
		brain.pendingMode = mode
		brain.pendingAt = now + reaction()
	end
	if now >= brain.pendingAt then
		brain.mode = mode
		brain.pendingMode = nil
		brain.waypoints = nil
		brain.goal = nil
		return true
	end
	return false
end

local function chase(brain: Brain, params: RaycastParams)
	local runners = others(brain.bot, "Runner")
	if #runners == 0 then
		brain.goal = nil
		return
	end
	local now = os.clock()
	local position = brain.root.Position
	-- Its share the Runners: a Runner another It is nearer to (a bot after them, or a player It
	-- close by) is theirs, so two Its don't chase one Runner while others run free.
	local its = others(brain.bot, "It")
	local function takenBy(runner: { contestant: any, root: BasePart }, mine: number): boolean
		for _, it in its do
			local theirs = (it.root.Position - runner.root.Position).Magnitude
			if theirs < mine then
				local other = brains[it.contestant]
				if other then
					if other.target == runner.contestant then
						return true
					end
				elseif theirs < Config.Bots.ShareDistance then
					return true
				end
			end
		end
		return false
	end
	-- Real players come first: they count PreferPlayers studs nearer than they are. A bot
	-- Runner within CloseBot that this It hasn't tagged yet this round counts the same as a
	-- player, so it goes for one right next to it (unless a player is nearer still).
	local settings = Config.Bots
	local function score(runner: { contestant: any, root: BasePart }, distance: number): number
		if not Contestant.isBot(runner.contestant) then
			return distance - settings.PreferPlayers
		end
		if distance < settings.CloseBot and not hasTagged(brain.bot, runner.contestant) then
			return distance - settings.PreferPlayers
		end
		return distance
	end
	-- Stick with a target for a moment unless another scores much better.
	local current, currentScore = nil, math.huge
	local best, bestScore = nil, math.huge
	local free, freeScore = nil, math.huge
	-- Runners it found no way to are left be for a while, unless nobody else is left.
	local reachable = {}
	for _, runner in runners do
		if (brain.noPath[runner.contestant] or 0) < now then
			table.insert(reachable, runner)
		end
	end
	if #reachable > 0 then
		runners = reachable
	end
	for _, runner in runners do
		local distance = (runner.root.Position - position).Magnitude
		local taken = takenBy(runner, distance)
		local value = score(runner, distance)
		if runner.contestant == brain.target and not taken then
			current, currentScore = runner, value
		end
		if value < bestScore then
			best, bestScore = runner, value
		end
		if not taken and value < freeScore then
			free, freeScore = runner, value
		end
	end
	-- (Every Runner taken: the best anyway.)
	local chosen = free or best
	if current and now - brain.targetSince < 2 and currentScore < freeScore + 12 then
		chosen = current
	end
	if not chosen then
		return
	end
	if chosen.contestant ~= brain.target then
		brain.target = chosen.contestant
		brain.targetSince = now
		brain.inReachSince = nil
		brain.swingAt = nil
	end
	local targetRoot = chosen.root
	local distance = (targetRoot.Position - position).Magnitude
	-- (Goals are floor spots: the target's feet.) On its own level it aims ahead of where the
	-- Runner is running; on another (up a ladder, a ramp, stairs) it heads for the floor right
	-- under them, so the path goes up to where they are (aiming ahead could put the goal off the
	-- edge of their ledge, or in the air while they jump).
	local feet = targetRoot.Position - UP * rootHeight(brain)
	local myFeet = position.Y - rootHeight(brain)
	local aim
	if math.abs(feet.Y - myFeet) < 2.5 then
		aim = feet + flat(targetRoot.AssemblyLinearVelocity) * Config.Bots.Lead
	else
		-- (Straight down from their middle: a ray from above could land on a ceiling.)
		local below = workspace:Raycast(targetRoot.Position, -UP * 14, params)
		aim = if below then below.Position else feet
	end
	goTo(brain, aim, params)
	brain.sprint = true

	-- Swinging: a beat after it's in reach; now and then a beat too early.
	local range = Config.Tag.Range
	if distance <= range * Config.Bots.SwingReach then
		if not brain.inReachSince then
			brain.inReachSince = now
			brain.swingAt = now + reaction()
		end
	else
		brain.inReachSince = nil
		if
			not brain.swingAt
			and distance <= range * 1.6
			and random:NextNumber() < Config.Bots.SwingMiss * Config.Bots.Think * 4
		then
			brain.swingAt = now + reaction() * 0.5 -- mistimed: swings before it's in reach
		end
	end
	if brain.swingAt and now >= brain.swingAt and now >= brain.pauseUntil then
		brain.swingAt = nil
		brain.inReachSince = nil
		local tagged = TagService.swing(brain.bot)
		if tagged then
			rememberTag(brain.bot, tagged)
		end
	end

	-- A slide into a straight chase.
	if
		brain.direct
		and distance > 10
		and distance < 26
		and random:NextNumber() < Config.Bots.SlideChance * Config.Bots.Think
	then
		slide(brain)
	end
end

local function run(brain: Brain, params: RaycastParams)
	local its = others(brain.bot, "It")
	local position = brain.root.Position
	local nearest, nearestDistance = nil, math.huge
	for _, it in its do
		if not Roles.isFrozen(it.contestant) then
			local distance = (it.root.Position - position).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = it, distance
			end
		end
	end
	local now = os.clock()
	local settings = Config.Bots

	-- Dodging an It that is closing in: decided once per approach, a beat late.
	if nearest and nearestDistance < settings.DodgeDistance then
		local closing =
			flat(nearest.root.AssemblyLinearVelocity - brain.root.AssemblyLinearVelocity)
		local toMe = flat(position - nearest.root.Position)
		local approaching = toMe.Magnitude > 0.1 and closing:Dot(toMe.Unit) > 4
		if approaching and brain.dodgeThreat ~= nearest.contestant and now > brain.dodgeUntil then
			brain.dodgeThreat = nearest.contestant
			if random:NextNumber() < settings.DodgeChance then
				local side = Vector3.new(-toMe.Z, 0, toMe.X).Unit
				-- The side with room (and away from the It's own sideways drift).
				if clearLine(position, position - side * 8, params) then
					if
						not clearLine(position, position + side * 8, params)
						or closing:Dot(side) > 0
					then
						side = -side
					end
				end
				local away = toMe.Unit
				brain.dodgeDir = (side * 1.2 + away).Unit
				brain.dodgeUntil = now + reaction() + 0.35
				local roll = random:NextNumber()
				if roll < 0.35 then
					brain.humanoid.Jump = true
				elseif roll < 0.7 then
					brain.dodgeDir = (away + side * 0.4).Unit
					slide(brain)
				end
			end
		end
	elseif nearest and nearestDistance > settings.DodgeDistance * 1.6 then
		brain.dodgeThreat = nil -- a new approach can be dodged again
	end

	-- No camping: a Runner that has stayed within CampRadius of one place for CampTime moves
	-- on, somewhere out of that area (and tries again a moment later if it didn't get out).
	if flat(position - brain.campFrom).Magnitude > settings.CampRadius then
		brain.campFrom = position
		brain.campSince = now
	end
	local camping = now - brain.campSince > settings.CampTime
	local avoid = if camping then brain.campFrom else nil
	if camping then
		brain.campSince = now - settings.CampTime + 1.5
		brain.goal = nil
		brain.waypoints = nil
	end

	-- Running from an It: from FleeDistance until every It is past CalmDistance.
	local fleeing = nearest ~= nil
		and (
			nearestDistance < settings.FleeDistance
			or (brain.mode == "Flee" and nearestDistance < settings.CalmDistance)
		)
	if fleeing and nearest then
		if want(brain, "Flee") then
			brain.sprint = true
			local reached = brain.goal and (flat(brain.goal - position)).Magnitude < 4
			local stale = now - brain.pathAt > settings.PathRefresh * 2
			if not brain.goal or reached or stale then
				-- (An It right on it: getting away comes first, wherever that is.)
				local panicking = nearestDistance < settings.FleeDistance * 0.6
				local spot =
					escapeSpot(brain, its, params, panicking, if panicking then nil else avoid)
				if spot then
					goTo(brain, spot, params)
					brain.pathAt = math.max(brain.pathAt, now - settings.PathRefresh) -- keep it a while
				end
			end
			-- Flat out and a clear way ahead: a slide now and then.
			if
				brain.direct
				and nearestDistance < 16
				and random:NextNumber() < settings.SlideChance * settings.Think
			then
				slide(brain)
			end
		end
	else
		if want(brain, "Roam") then
			brain.sprint = camping or (nearest ~= nil and nearestDistance < settings.CalmDistance)
			-- Keeps on the move: a short look round where it got to, then somewhere new.
			local reached = brain.goal and flat(brain.goal - position).Magnitude < 4
			if reached and brain.roamUntil > now + 1.2 then
				brain.roamUntil = now + rnd(0.3, 1.2)
			end
			if not brain.goal or now > brain.roamUntil then
				brain.roamUntil = now + rnd(3, 6)
				local spot = escapeSpot(brain, its, params, false, avoid)
				if avoid and (not spot or flat(spot - avoid).Magnitude < settings.CampRadius) then
					spot = farSpot(avoid) or spot
				end
				spot = spot or roamSpot(brain, params, nil)
				if spot then
					goTo(brain, spot, params)
				end
			end
		end
	end
end

-- Between rounds and in the lobby: a slow wander round where it stands.
local function wander(brain: Brain, params: RaycastParams)
	local now = os.clock()
	brain.sprint = false
	brain.mode = "Roam"
	if now > brain.roamUntil then
		brain.roamUntil = now + rnd(3, 8)
		if random:NextNumber() < 0.35 then
			brain.goal = nil -- stand a while
		else
			local home = if GameState.getPhase() == "Results" then nil else Config.Lobby.Position
			local spot = roamSpot(brain, params, home)
			if spot then
				goTo(brain, spot, params)
			end
		end
	end
end

local function think(brain: Brain)
	local params = rayParams()
	local phase = GameState.getPhase()
	local frozen = Roles.isFrozen(brain.bot)
	-- Just tagged (Runner to It mid-round): it can't swing for a moment (it still chases).
	local role = Roles.get(brain.bot)
	if role ~= brain.role then
		if role == "It" and brain.role == "Runner" and phase == "Playing" then
			brain.pauseUntil = os.clock() + Config.Bots.TaggedPause
			brain.swingAt = nil
			brain.inReachSince = nil
		end
		brain.role = role
	end
	if phase == "Intro" or phase == "Victory" or frozen then
		brain.goal = nil
		brain.waypoints = nil
		brain.mode = "Idle"
		return
	end
	checkLaunch(brain, params)
	if phase == "Playing" and Participants.isAlive(brain.bot) then
		if role == "It" then
			brain.mode = "Chase"
			chase(brain, params)
		elseif role == "Runner" then
			run(brain, params)
		end
	elseif not GAME_PHASES[phase] or phase == "Results" then
		wander(brain, params)
	end
end

-- Steering ----------------------------------------------------------------------------------

local function unstick(brain: Brain, moving: boolean)
	local now = os.clock()
	local position = brain.root.Position
	if not moving or (position - brain.progressFrom).Magnitude > 1.5 then
		brain.progressFrom = position
		brain.progressAt = now
		brain.stuckTries = 0
		return
	end
	if now - brain.progressAt > Config.Bots.StuckTime then
		brain.progressAt = now
		brain.stuckTries += 1
		brain.humanoid.Jump = true
		if brain.stuckTries >= 2 then
			-- Still stuck: make a new path, or give up on this spot.
			brain.waypoints = nil
			brain.direct = false
			brain.pathAt = 0
			if brain.stuckTries >= 3 then
				brain.goal = nil
				brain.roamUntil = 0
				brain.stuckTries = 0
			end
		end
	end
end

local function steer(brain: Brain)
	local now = os.clock()
	local humanoid, root = brain.humanoid, brain.root
	local state = Bots.state(brain.bot)
	local frozen = Roles.isFrozen(brain.bot)
	local stunned = state ~= nil and now < state.stunUntil

	-- Speed: the role's speed, sprinting like a player, a slide's burst fading back.
	if not frozen then
		local role = Roles.get(brain.bot)
		local base = if role == "It" then Config.Speed.It else Config.Speed.Runner
		local speed = if brain.sprint then base * Config.Sprint.Multiplier else base
		if brain.slideUntil > now then
			local alpha = (now - brain.slideStart) / Config.Bots.SlideTime
			speed = base
				* Config.Sprint.Multiplier
				* (1 + (Config.Bots.SlideBoost - 1) * (1 - alpha))
		elseif brain.slideUntil > 0 then
			-- Slide over: stand up unless something is overhead.
			local params = rayParams()
			if workspace:Raycast(root.Position, UP * (Config.Slide.HeadClearance + 1), params) then
				brain.slideUntil = now + 0.2
			else
				endSlide(brain)
			end
		end
		humanoid.WalkSpeed = speed
	end

	local dir = Vector3.zero
	if not frozen and not stunned then
		if brain.dodgeDir and now < brain.dodgeUntil then
			dir = brain.dodgeDir
		elseif brain.slideUntil > now and brain.lastDir.Magnitude > 0.1 then
			dir = brain.lastDir -- a slide keeps its line, turning a little toward the goal
			local goal = brain.goal
			if goal then
				local to = flat(goal - root.Position)
				if to.Magnitude > 1 then
					dir = (dir * 4 + to.Unit).Unit
				end
			end
		else
			brain.dodgeDir = nil
			local waypoints = brain.waypoints
			local target: Vector3? = nil
			-- Waypoints and goals are spots on the floor: measured from the feet.
			local feet = root.Position - UP * rootHeight(brain)
			if waypoints and not brain.direct then
				local waypoint = waypoints[brain.waypoint]
				while waypoint do
					local to = waypoint.Position - feet
					local close = flat(to).Magnitude < 2.2
					local climbing = humanoid:GetState() == Enum.HumanoidStateType.Climbing
					if close and (math.abs(to.Y) < 2.5 or (climbing and to.Y < 1)) then
						brain.waypoint += 1
						waypoint = waypoints[brain.waypoint]
						if waypoint and waypoint.Action == Enum.PathWaypointAction.Jump then
							humanoid.Jump = true
						end
					else
						break
					end
				end
				if waypoint then
					target = waypoint.Position
				else
					brain.waypoints = nil
					target = brain.goal
				end
			elseif brain.goal then
				target = brain.goal
			end
			if target then
				local to = flat(target - root.Position)
				if to.Magnitude > 1 then
					dir = to.Unit
				elseif brain.lastDir.Magnitude > 0.1 and target.Y > feet.Y + 2 then
					dir = brain.lastDir -- right under a ladder's next rung: keep pushing into it
				end
			end
		end
	end

	-- Never step off a deadly drop.
	if dir.Magnitude > 0.1 and dangerous() and humanoid.FloorMaterial ~= Enum.Material.Air then
		local params = rayParams()
		local ahead = root.Position + dir * 3
		local floor = floorAt(ahead, params, Config.Bots.DangerDrop + 3)
		local here = floorAt(root.Position, params, 8)
		if not floor or (here and here.Y - floor.Y > Config.Bots.DangerDrop) then
			dir = Vector3.zero
			brain.waypoints = nil
			brain.goal = nil
			brain.roamUntil = 0
			if brain.slideUntil > 0 then
				endSlide(brain)
			end
		end
	end

	if dir.Magnitude > 0.1 then
		brain.lastDir = dir
	end
	humanoid:Move(dir, false)
	unstick(brain, dir.Magnitude > 0.1)
	animate(brain)
end

-- Setting up ------------------------------------------------------------------------------

local function attach(bot: ObjectValue, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not humanoid or not root or bot.Value ~= character then
		return
	end
	local old = brains[bot]
	if old and old.flight then
		old.flight:Destroy()
	end
	local now = os.clock()
	brains[bot] = {
		bot = bot,
		character = character,
		humanoid = humanoid,
		root = root,
		tracks = {},
		playing = nil,
		standingHip = humanoid.HipHeight,
		mode = "Idle",
		pendingMode = nil,
		pendingAt = 0,
		goal = nil,
		direct = false,
		waypoints = nil,
		waypoint = 2,
		pathFor = nil,
		pathAt = 0,
		computing = false,
		lastDir = Vector3.zero,
		sprint = false,
		nextThink = now + rnd(0, Config.Bots.Think),
		roamUntil = 0,
		role = Roles.get(bot), -- (a respawn on the map keeps the role: no pause)
		pauseUntil = 0,
		target = nil,
		noPath = {},
		targetSince = 0,
		inReachSince = nil,
		swingAt = nil,
		slideUntil = 0,
		slideStart = 0,
		lastSlide = 0,
		dodgeDir = nil,
		dodgeUntil = 0,
		dodgeThreat = nil,
		flight = nil,
		launchCheck = 0,
		campFrom = root.Position,
		campSince = now,
		progressAt = now,
		progressFrom = root.Position,
		stuckTries = 0,
	}
end

function BotBrain.start()
	Bots.onCharacterAdded(attach)
	Bots.onRemoved(function(bot)
		brains[bot] = nil
		taggedBy[bot] = nil
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for bot, brain in brains do
			local character = brain.character
			if bot.Value ~= character or not character.Parent then
				brains[bot] = nil
				continue
			end
			if brain.humanoid.Health <= 0 or character:GetAttribute("Parked") then
				continue
			end
			if now >= brain.nextThink then
				brain.nextThink = now + Config.Bots.Think
				local ok, err = pcall(think, brain)
				if not ok then
					warn(`[BotBrain] {bot.Name}: {err}`)
				end
			end
			local ok, err = pcall(steer, brain)
			if not ok then
				warn(`[BotBrain] {bot.Name}: {err}`)
			end
		end
	end)
end

return BotBrain
