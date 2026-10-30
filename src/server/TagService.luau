--!strict
-- Swings: anyone left-clicks to swing (client/TagSwing sends a TagSwing remote). The server
-- checks the swing is allowed (not frozen, off cooldown) and tells every client to play the
-- swipe. It's swing during a round tags the nearest Runner within Config.Tag.Range; any other
-- swing (a Runner's, It with no Runner in reach, or outside a round) shoves the nearest player in
-- reach. A hit pushes the player hit (Config.Knockback): harder the faster the swinger was moving
-- at them; their own client applies it (TagKnockback). Misses still swing. Tags freeze nobody
-- and there is no tag-back protection: the knockback is what gives space.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local GameLog = require(script.Parent.GameLog)
local Leaderstats = require(script.Parent.Leaderstats)
local Participants = require(script.Parent.Participants)
local Progression = require(script.Parent.Progression)
local Roles = require(script.Parent.Roles)
local RoundStats = require(script.Parent.RoundStats)

local TagService = {}

local lastSwing: { [Player]: number } = {}

-- While a game is being played only the players still in it take part: swings from, and hits on,
-- anyone else (eliminated, spectating, joined late) are ignored. Elsewhere (the lobby, the
-- sandbox, the victory screen) everyone does.
local GAME_PHASES = { Intro = true, Playing = true, Results = true }

local function takesPart(player: Player): boolean
	return not GAME_PHASES[GameState.getPhase()]
		or Participants.isAlive(player)
		or player:GetAttribute("LeftEarly") == true -- back in the lobby: shoves work there
end

local function flatSpeed(root: BasePart): number
	local v = root.AssemblyLinearVelocity
	return math.floor(Vector3.new(v.X, 0, v.Z).Magnitude * 10 + 0.5) / 10
end

-- Returns the player's root part only if their character is alive.
local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Pushes `hit` away from the swinger: Base plus PerSpeed of the swinger's speed toward them,
-- times `scale` (a shove's Shove). Their client applies it (and more if they're in the air).
local function knockback(swingerRoot: BasePart, hit: Player, scale: number)
	local root = aliveRoot(hit)
	if not root then
		return
	end
	local settings = Config.Knockback
	local offset = root.Position - swingerRoot.Position
	local direction = Vector3.new(offset.X, 0, offset.Z)
	if direction.Magnitude < 0.1 then
		local look = swingerRoot.CFrame.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit
	local v = swingerRoot.AssemblyLinearVelocity
	local closing = math.max(Vector3.new(v.X, 0, v.Z):Dot(direction), 0)
	local strength = math.min(settings.Base + settings.PerSpeed * closing, settings.Max) * scale
	if strength > 0 then
		Remotes.get("TagKnockback"):FireClient(hit, direction * strength)
	end
end

local function tag(tagger: Player, tagged: Player, distance: number?, taggerSpeed: number?)
	if GameLog.enabled() then
		local taggedRoot = aliveRoot(tagged)
		local distanceText = if distance then string.format("%.1f", distance) else "?"
		local taggedSpeed = if taggedRoot then flatSpeed(taggedRoot) else "?"
		GameLog.say(
			`TAG {tagger.Name} -> {tagged.Name} at {distanceText} studs (range {Config.Tag.Range}); speeds: {tagger.Name} {taggerSpeed or "?"}, {tagged.Name} {taggedSpeed}`
		)
	end
	Roles.set(tagger, "Runner")
	Roles.set(tagged, "It")
	RoundStats.tagged(tagger, tagged)
	Leaderstats.add(tagger, "Tags", 1)
	Progression.record(tagger, "Tag")
	Remotes.get("TagHit"):FireAllClients(tagger, tagged) -- the tagger's tag effect
	GameState.setStatus(`{tagger.DisplayName} tagged {tagged.DisplayName}!`)
end

-- The nearest other player within reach of `fromRoot` (only Runners with `runnersOnly`), if any.
local function nearest(swinger: Player, fromRoot: BasePart, runnersOnly: boolean): Player?
	local best: Player? = nil
	local bestDistance = Config.Tag.Range
	for _, other in Players:GetPlayers() do
		if
			other ~= swinger
			and takesPart(other)
			and (not runnersOnly or Roles.get(other) == "Runner")
		then
			local root = aliveRoot(other)
			local distance = root and (root.Position - fromRoot.Position).Magnitude
			if distance and distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

-- For the log: how far the nearest Runner was when It swung and missed (however far away).
local function logMiss(swinger: Player, fromRoot: BasePart)
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= swinger and takesPart(other) and Roles.get(other) == "Runner" then
			local root = aliveRoot(other)
			local distance = root and (root.Position - fromRoot.Position).Magnitude
			if distance and distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	local nearestText = "none"
	if best then
		nearestText = `{best.Name} at {string.format("%.1f", bestDistance)}`
	end
	GameLog.say(
		`SWING by It {swinger.Name} hit nobody (speed {flatSpeed(fromRoot)}); nearest Runner: {nearestText} studs, range {Config.Tag.Range}`
	)
end

local function onSwing(player: Player)
	if not takesPart(player) then
		return
	end
	-- Anyone can swing, just not while frozen or faster than the cooldown allows.
	if Roles.isFrozen(player) then
		return
	end
	local now = os.clock()
	if now - (lastSwing[player] or -math.huge) < Config.Tag.Cooldown then
		return
	end
	lastSwing[player] = now
	local root = aliveRoot(player)
	if not root then
		return
	end
	Remotes.get("TagSwingPlayed"):FireAllClients(player)
	-- It tags a Runner during a round; every other hit is a shove.
	local phase = GameState.getPhase()
	local tagging = Roles.get(player) == "It" and (phase == "Playing" or phase == "Sandbox")
	local target = if tagging then nearest(player, root, true) else nil
	if target then
		local targetRoot = aliveRoot(target)
		tag(
			player,
			target,
			if targetRoot then (targetRoot.Position - root.Position).Magnitude else nil,
			flatSpeed(root)
		)
		knockback(root, target, 1)
		return
	end
	if tagging and GameLog.enabled() then
		logMiss(player, root)
	end
	local shoved = nearest(player, root, false)
	if shoved then
		knockback(root, shoved, Config.Knockback.Shove)
	end
end

function TagService.start()
	Remotes.get("TagSwing").OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return TagService
