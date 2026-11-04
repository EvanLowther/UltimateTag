--!strict
-- The bots themselves: making them, their bodies, respawning, removing them. Each bot is an
-- ObjectValue in ReplicatedStorage.Bots (shared/Contestant) that every client sees: its Value is
-- its character, its attributes are the same ones a player carries (Role, InGame, Alive...) plus
-- DisplayName and UserId (-1, -2...: never a real player's). Its body is a copy of the game's
-- StarterCharacter in its own colors (Config.Bots.Colors), with a BOT tag over its head, owned by
-- the server (it runs the bot's physics). What a bot does is server/BotBrain.
--   fill(count)   makes or removes bots until there are `count` (bots in a game stay)
--   loadCharacter(bot, at)   a new body at `at`, or on the lobby's spawn ring
--   knockback(bot, push)     a hit's push (server/TagService), like client/Knockback does for players
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Contestant = require(Shared.Contestant)

local Bots = {}

export type State = {
	bot: ObjectValue,
	index: number, -- which of Config.Bots.Names
	stunUntil: number, -- os.clock() until which a hit has taken its control
	animations: { [string]: Animation }, -- idle, walk, run, jump, fall, climb
}

local states: { [ObjectValue]: State } = {}
local characterListeners: { (ObjectValue, Model) -> () } = {}
local removedListeners: { (ObjectValue) -> () } = {}
local folder: Folder

local INK = Color3.fromRGB(17, 17, 17)
local YELLOW = Color3.fromRGB(255, 214, 0)
local DISPLAY = Font.new("rbxasset://fonts/families/Bangers.json")
local HEAVY = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Heavy)

function Bots.list(): { ObjectValue }
	return Contestant.bots() :: any
end

function Bots.state(bot: ObjectValue): State?
	return states[bot]
end

-- Calls `listener(bot, character)` each time a bot gets a new body.
function Bots.onCharacterAdded(listener: (ObjectValue, Model) -> ())
	table.insert(characterListeners, listener)
end

-- Calls `listener(bot)` when a bot is removed.
function Bots.onRemoved(listener: (ObjectValue) -> ())
	table.insert(removedListeners, listener)
end

-- The animations of Roblox's Animate script on the StarterCharacter (it's a LocalScript, which
-- doesn't run in a bot, so server/BotBrain plays them itself).
local function animationsFrom(template: Model): { [string]: Animation }
	local found: { [string]: Animation } = {}
	local animate = template:FindFirstChild("Animate")
	if not animate then
		return found
	end
	for _, name in { "idle", "walk", "run", "jump", "fall", "climb" } do
		local holder = animate:FindFirstChild(name)
		local animation = holder and holder:FindFirstChildOfClass("Animation")
		if animation then
			found[name] = animation
		end
	end
	return found
end

-- A spot on the lobby's spawn ring.
local function lobbySpot(): CFrame
	local lobby = workspace:FindFirstChild("Lobby")
	local spots = {}
	if lobby then
		for _, item in lobby:GetDescendants() do
			if item:IsA("SpawnLocation") then
				table.insert(spots, item)
			end
		end
	end
	if #spots == 0 then
		return CFrame.new(Config.Lobby.Position + Vector3.new(0, 5, 0))
	end
	local spot = spots[math.random(#spots)] :: SpawnLocation
	return spot.CFrame + Vector3.new(0, 3, 0)
end

-- The BOT tag and the bot's name over its head, in the Street sprint style.
local function nameTag(head: BasePart, name: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BotTag"
	gui.Size = UDim2.fromOffset(220, 54)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	local content = Instance.new("Frame")
	content.Name = "Content" -- (client/HeadTags scales this with distance, from its bottom)
	content.BackgroundTransparency = 1
	content.AnchorPoint = Vector2.new(0.5, 1)
	content.Position = UDim2.fromScale(0.5, 1)
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = gui
	local pill = Instance.new("TextLabel")
	pill.Name = "Bot"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0)
	pill.Size = UDim2.fromOffset(46, 18)
	pill.BackgroundColor3 = YELLOW
	pill.BorderSizePixel = 0
	pill.FontFace = HEAVY
	pill.TextSize = 14
	pill.TextColor3 = INK
	pill.Text = Config.Bots.TagText
	pill.Parent = content
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Position = UDim2.fromOffset(0, 20)
	label.Size = UDim2.new(1, 0, 0, 32)
	label.BackgroundTransparency = 1
	label.FontFace = DISPLAY
	label.TextSize = 26
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = name
	label.Parent = content
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	gui.Parent = head
end

local function paint(character: Model, index: number)
	local colors = Config.Bots.Colors[((index - 1) % #Config.Bots.Colors) + 1]
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors and colors then
		bodyColors.TorsoColor3 = colors[1]
		bodyColors.LeftArmColor3 = colors[2]
		bodyColors.RightArmColor3 = colors[2]
		bodyColors.LeftLegColor3 = colors[3]
		bodyColors.RightLegColor3 = colors[3]
	end
end

-- A new body for `bot` at `at` (or on the lobby's spawn ring); the old one goes.
function Bots.loadCharacter(bot: ObjectValue, at: CFrame?)
	local state = states[bot]
	local template = StarterPlayer:FindFirstChild("StarterCharacter")
	if not state or not template or not template:IsA("Model") then
		return
	end
	local old = bot.Value
	bot.Value = nil
	if old then
		old:Destroy()
	end
	if not next(state.animations) then
		state.animations = animationsFrom(template)
	end
	local character = template:Clone()
	for _, item in character:GetDescendants() do
		if item:IsA("BaseScript") then
			item:Destroy()
		end
	end
	local displayName = bot:GetAttribute("DisplayName") or bot.Name
	character.Name = displayName
	character:SetAttribute("Bot", bot.Name)
	paint(character, state.index)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		character:Destroy()
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		nameTag(head, displayName)
	end
	character:PivotTo(at or lobbySpot())
	character.Parent = workspace
	pcall(function()
		root:SetNetworkOwner(nil) -- the server runs a bot's physics
	end)
	bot.Value = character
	state.stunUntil = 0

	humanoid.Died:Connect(function()
		task.delay(Config.Game.RespawnTime, function()
			if states[bot] and bot.Value == character then
				Bots.loadCharacter(bot)
			end
		end)
	end)
	for _, listener in characterListeners do
		task.spawn(listener, bot, character)
	end
end

-- Makes the next free bot (nil if every name is taken), standing in the lobby.
function Bots.add(): ObjectValue?
	local used: { [string]: boolean } = {}
	for _, bot in Bots.list() do
		used[bot.Name] = true
	end
	for index, name in Config.Bots.Names do
		if not used[name] then
			local bot = Instance.new("ObjectValue")
			bot.Name = name
			bot:SetAttribute("DisplayName", name)
			bot:SetAttribute("UserId", -index)
			bot:SetAttribute("IsBot", true)
			states[bot] = { bot = bot, index = index, stunUntil = 0, animations = {} }
			bot.Parent = folder
			Bots.loadCharacter(bot)
			return bot
		end
	end
	return nil
end

function Bots.remove(bot: ObjectValue)
	if not states[bot] then
		return
	end
	states[bot] = nil
	local character = bot.Value
	bot.Value = nil
	if character then
		character:Destroy()
	end
	for _, listener in removedListeners do
		task.spawn(listener, bot)
	end
	bot:Destroy()
end

function Bots.removeAll()
	for _, bot in Bots.list() do
		Bots.remove(bot)
	end
end

-- Makes or removes bots until there are `count` (never more than there are names). Bots still
-- in a running game are the last to go.
function Bots.fill(count: number)
	local target = math.clamp(count, 0, #Config.Bots.Names)
	local bots = Bots.list()
	table.sort(bots, function(a, b)
		local aIn = a:GetAttribute("InGame") == true
		local bIn = b:GetAttribute("InGame") == true
		if aIn ~= bIn then
			return bIn -- out of the game first
		end
		return (a:GetAttribute("UserId") or 0) < (b:GetAttribute("UserId") or 0) -- newest first
	end)
	local i = 1
	while #bots - (i - 1) > target do
		Bots.remove(bots[i])
		i += 1
	end
	for _ = 1, target - #Bots.list() do
		if not Bots.add() then
			break
		end
	end
end

-- A hit's push, the way client/Knockback applies it to a player: stronger and with a bigger pop
-- if the bot is in the air. The bot loses control for Config.Bots.KnockbackStun.
function Bots.knockback(bot: ObjectValue, push: Vector3)
	local state = states[bot]
	local character = bot.Value :: Model?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not state or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local settings = Config.Knockback
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	local across = if airborne then push * settings.AirMultiplier else push
	local pop = if airborne then settings.AirPop else settings.Pop
	local stun = Config.Bots.KnockbackStun
	state.stunUntil = os.clock() + stun
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity =
		Vector3.new(across.X, math.max(root.AssemblyLinearVelocity.Y, 0) + pop, across.Z)
	-- The push across, held and fading over the stun (the humanoid would cancel it on landing).
	local attachment = Instance.new("Attachment")
	attachment.Name = "BotKnockback"
	attachment.Parent = root
	local drive = Instance.new("LinearVelocity")
	drive.Attachment0 = attachment
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.MaxForce = 1e6
	drive.PlaneVelocity = Vector2.new(across.X, across.Z)
	drive.Parent = root
	task.spawn(function()
		local started = os.clock()
		while drive.Parent and os.clock() - started < stun do
			local fade = 1 - (os.clock() - started) / stun
			drive.PlaneVelocity = Vector2.new(across.X, across.Z) * fade
			task.wait()
		end
		drive:Destroy()
		attachment:Destroy()
	end)
end

function Bots.start()
	folder = Instance.new("Folder")
	folder.Name = Contestant.FolderName
	folder.Parent = ReplicatedStorage
	-- Nobody left to play with: the bots go too.
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if #Players:GetPlayers() == 0 then
				Bots.removeAll()
			end
		end)
	end)
end

return Bots
