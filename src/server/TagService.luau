--!strict
-- Swings: anyone left-clicks to swing (client/TagSwing sends a TagSwing remote). The server
-- checks the swing is allowed (not frozen, off cooldown) and tells every client to play the
-- swipe. It's swing during a round tags the nearest Runner within Config.Tag.Range; any other
-- swing (a Runner's, It with no Runner in reach, or outside a round) shoves the nearest player in
-- reach. A hit pushes the player hit (Config.Knockback): harder the faster the swinger was moving
-- at them; their own client applies it (TagKnockback). Misses still swing. Tags freeze nobody
-- and there is no tag-back protection: the knockback is what gives space.
-- A player's swing is easier than a bot's: their screen (client/TagSwing) picks who they hit,
-- anyone within Config.Tag.PlayerRange or AimRange near the aim ring, and the server takes it
-- if that one is within AimRange (plus Tolerance and the ping allowance) here too. A player's
-- swing that hit nobody stays live for Window: a later hit from their screen still tags.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Contestant = require(Shared.Contestant)
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local Bots = require(script.Parent.Bots)
local GameLog = require(script.Parent.GameLog)
local Leaderstats = require(script.Parent.Leaderstats)
local Participants = require(script.Parent.Participants)
local Progression = require(script.Parent.Progression)
local Roles = require(script.Parent.Roles)
local RoundStats = require(script.Parent.RoundStats)

local TagService = {}

local lastSwing: { [Player]: number } = {}
local liveSwing: { [Player]: number } = {} -- an It's swing that hit nobody yet (its time)

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
	local character = Contestant.character(player)
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
		if Contestant.isBot(hit) then
			Bots.knockback(hit :: any, direction * strength) -- the server runs a bot's body
		else
			Remotes.get("TagKnockback"):FireClient(hit, direction * strength)
		end
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
	Remotes.get("TagHit"):FireAllClients(tagger, tagged) -- the tagger's tag effect (no status line)
end

-- How much further than Config.Tag.Range a swing reaches `other` in a live server: the server
-- sees both players a ping late, so they can be further apart here than on the swinger's screen
-- (their speed relative to each other times both pings). Nothing in Studio (no ping).
local function lagExtra(swinger: Player, fromRoot: BasePart, other: Player, root: BasePart): number
	local settings = Config.Tag
	-- (A bot has no ping: the server runs it.)
	local ok, ping = pcall(function()
		local function pingOf(contestant: any): number
			return if Contestant.isBot(contestant) then 0 else contestant:GetNetworkPing()
		end
		return pingOf(swinger) + pingOf(other)
	end)
	if not ok or type(ping) ~= "number" then
		return 0
	end
	local relative = root.AssemblyLinearVelocity - fromRoot.AssemblyLinearVelocity
	return math.min(
		relative.Magnitude * math.clamp(ping, 0, settings.LagTime),
		settings.LagMaxExtra
	)
end

-- Can `other` be hit by `swinger` (a Runner for a tag with `runnersOnly`)?
local function hittable(swinger: Player, other: any, runnersOnly: boolean): boolean
	-- (A player, or a bot in the bots' folder: a client could send any instance.)
	return typeof(other) == "Instance"
		and other ~= swinger
		and (other:IsA("Player") or (Contestant.isBot(other) and other.Parent == Contestant.folder()))
		and Contestant.present(other)
		and takesPart(other)
		and (not runnersOnly or Roles.get(other) == "Runner")
end

-- How far `swinger`'s swing reaches: bots Config.Tag.Range, players PlayerRange.
local function reachOf(swinger: Player): number
	return if Contestant.isBot(swinger) then Config.Tag.Range else Config.Tag.PlayerRange
end

-- The one `swinger`'s screen says they hit, if they're in reach here too.
local function claimed(
	swinger: Player,
	fromRoot: BasePart,
	other: any,
	runnersOnly: boolean
): Player?
	if Contestant.isBot(swinger) or not hittable(swinger, other, runnersOnly) then
		return nil
	end
	local root = aliveRoot(other)
	if not root then
		return nil
	end
	local settings = Config.Tag
	local reach = math.max(settings.AimRange, settings.PlayerRange)
		+ settings.Tolerance
		+ lagExtra(swinger, fromRoot, other, root)
	if (root.Position - fromRoot.Position).Magnitude <= reach then
		return other
	end
	return nil
end

-- The nearest other player within reach of `fromRoot` (only Runners with `runnersOnly`), if any.
local function nearest(swinger: Player, fromRoot: BasePart, runnersOnly: boolean): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in Contestant.all() do
		if hittable(swinger, other, runnersOnly) then
			local root = aliveRoot(other)
			if root then
				local distance = (root.Position - fromRoot.Position).Magnitude
				local reach = reachOf(swinger) + lagExtra(swinger, fromRoot, other, root)
				if distance <= reach and distance < bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

-- For the log: how far the nearest Runner was when It swung and missed (however far away).
local function logMiss(swinger: Player, fromRoot: BasePart)
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in Contestant.all() do
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

local function isTagging(player: Player): boolean
	local phase = GameState.getPhase()
	return Roles.get(player) == "It" and (phase == "Playing" or phase == "Sandbox")
end

local function tagWith(player: Player, root: BasePart, target: Player)
	liveSwing[player] = nil
	local targetRoot = aliveRoot(target)
	tag(
		player,
		target,
		if targetRoot then (targetRoot.Position - root.Position).Magnitude else nil,
		flatSpeed(root)
	)
	knockback(root, target, 1)
end

-- A hit the player's screen saw just after a swing that hit nobody (within Config.Tag.Window).
local function onLateHit(player: Player, aimed: any)
	local swungAt = liveSwing[player]
	local settings = Config.Tag
	if not swungAt or os.clock() - swungAt > settings.Window + settings.LagTime then
		return
	end
	if not takesPart(player) or Roles.isFrozen(player) or not isTagging(player) then
		return
	end
	local root = aliveRoot(player)
	local target = root and claimed(player, root, aimed, true)
	if root and target then
		tagWith(player, root, target)
	end
end

-- `aimed`: who the player's screen says they hit (nil for bots, or if their screen saw nobody).
local function onSwing(player: Player, aimed: any?, late: any?)
	if late == true then
		onLateHit(player, aimed)
		return
	end
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
	local tagging = isTagging(player)
	local target = if tagging
		then claimed(player, root, aimed, true) or nearest(player, root, true)
		else nil
	if target then
		tagWith(player, root, target)
		return
	end
	if tagging then
		liveSwing[player] = now -- still live for Config.Tag.Window
		if GameLog.enabled() then
			logMiss(player, root)
		end
	end
	local shoved = claimed(player, root, aimed, false) or nearest(player, root, false)
	if shoved then
		knockback(root, shoved, Config.Knockback.Shove)
	end
end

-- A bot's swing (server/BotBrain): the same as a player's left click.
function TagService.swing(bot: any)
	onSwing(bot)
end

function TagService.start()
	Remotes.get("TagSwing").OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		liveSwing[player] = nil
	end)
end

return TagService
