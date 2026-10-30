--!strict
-- Players who are out of the game are camera only: no body in the world. While a game is on
-- (Intro, Playing, Results), anyone who is not still in it, whether eliminated, fell off the map
-- or joined late, is "parked": their character is anchored, invisible, without collision, and
-- moved far under the lobby (Config.Game.ParkOffset), and their `Spectating` player attribute is
-- set so client/Spectate takes the camera. Nobody can reach the park spot, it is not near any
-- kill height, and map hazards, tags and trains skip parked characters (the `Parked` attribute
-- on the character). When the game ends GameLoop calls `releaseAll` and respawns everyone in the
-- lobby.
--   eliminated(player)  the ELIMINATED moment: they stay visible and frozen for
--                       Config.Game.EliminatedTime, flashing red, then are parked.
--   park(player)        park now (also what a respawning out player gets, see `start`).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)
local GameLog = require(script.Parent.GameLog)
local Participants = require(script.Parent.Participants)
local Roles = require(script.Parent.Roles)

local Spectators = {}

local GAME_PHASES = { Intro = true, Playing = true, Results = true }
local FLASH_NAME = "EliminatedFlash"

-- Is a game being played right now, and is this player out of it? (Sandbox, the lobby, the
-- countdown and the victory screen never park anyone.)
function Spectators.shouldPark(player: Player): boolean
	return GAME_PHASES[GameState.getPhase()] == true and not Participants.isAlive(player)
end

function Spectators.isParked(character: Instance?): boolean
	return character ~= nil and character:GetAttribute("Parked") == true
end

-- Where this player's body goes: under the lobby, spread out a little.
local function parkSpot(player: Player): CFrame
	local spread = (player.UserId % 40) * 6
	return CFrame.new(Config.Lobby.Position + Config.Game.ParkOffset + Vector3.new(spread, 0, 0))
end

-- Makes a character unseen, untouchable and still, and moves it to the park spot.
local function hide(player: Player, character: Model)
	if Spectators.isParked(character) then
		return
	end
	character:SetAttribute("Parked", true)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	character:PivotTo(parkSpot(player))
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Transparency = 1
		elseif item:IsA("Highlight") then
			item:Destroy()
		elseif
			item:IsA("BillboardGui")
			or item:IsA("ParticleEmitter")
			or item:IsA("Trail")
			or item:IsA("Beam")
		then
			item.Enabled = false
		end
	end
	GameLog.say(`{player.Name} parked`)
end

-- Parks the player's current character (if it is alive; a dead one is parked when its
-- replacement spawns) and tells their client to start spectating.
function Spectators.park(player: Player)
	player:SetAttribute("Spectating", true)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		hide(player, character)
	end
end

-- A quick red flash over an eliminated player's body that fades out in `seconds`.
local function flash(character: Model, seconds: number)
	local highlight = Instance.new("Highlight")
	highlight.Name = FLASH_NAME
	highlight.FillColor = Config.Colors.It
	highlight.FillTransparency = 0.1
	highlight.OutlineColor = Config.Colors.Text
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	TweenService:Create(
		highlight,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
end

-- The ELIMINATED moment: `player` was just put out (Participants.eliminate). They stay where
-- they are, frozen and flashing, for Config.Game.EliminatedTime (their banner sweeps across
-- their screen and everyone sees who is out), then they are parked and start spectating. If the
-- game has moved on by then (it ended, or a new one started) nothing happens.
function Spectators.eliminated(player: Player)
	local seconds = Config.Game.EliminatedTime
	local gameNumber = Participants.gameId()
	Roles.freeze(player, seconds + 1)
	local character = player.Character
	if character then
		flash(character, seconds)
	end
	task.delay(seconds, function()
		if
			player.Parent
			and Participants.gameId() == gameNumber
			and Spectators.shouldPark(player)
		then
			Spectators.park(player)
		end
	end)
end

-- Out of the game with no moment to show (they died on the map and are respawning): they spectate
-- after the same wait, and whatever body they respawn with is parked (see `start`).
function Spectators.fellOut(player: Player)
	local gameNumber = Participants.gameId()
	task.delay(Config.Game.EliminatedTime, function()
		if
			player.Parent
			and Participants.gameId() == gameNumber
			and Spectators.shouldPark(player)
		then
			Spectators.park(player)
		end
	end)
end

-- Everyone back to normal (the game is over): nobody is spectating. Their parked characters are
-- replaced by the respawn that follows.
function Spectators.releaseAll()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Spectating", nil)
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		if not Spectators.shouldPark(player) then
			return
		end
		-- A body that spawns while its player is out of a running game (a late joiner, or the
		-- respawn after falling off) goes straight to the park spot.
		character:WaitForChild("HumanoidRootPart", 5)
		if Spectators.shouldPark(player) and character.Parent then
			Spectators.park(player)
		end
	end)
end

function Spectators.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Spectators
