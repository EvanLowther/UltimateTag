--!strict
-- Spectating. While a game is on and you're not in it (eliminated, or you joined mid-game),
-- the camera follows a player who is still in. Q / E (or the left / right arrows) switch
-- between them. When the game ends and everyone is back in the lobby, the camera comes back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(Shared:WaitForChild("GameState"))
local ViewMode = require(script.Parent.ViewMode)

local Spectate = {}

local GAME_PHASES = { Intro = true, Playing = true, Results = true, Victory = true }
local NEXT_KEYS = {
	[Enum.KeyCode.E] = 1,
	[Enum.KeyCode.Right] = 1,
	[Enum.KeyCode.Q] = -1,
	[Enum.KeyCode.Left] = -1,
}

-- Everyone still in the game, in a stable order (so switching goes round the same way).
local function alivePlayers(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("InGame") and other:GetAttribute("Alive") then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

function Spectate.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local target: Player? = nil
	local spectating = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "Spectate"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -24)
	label.Size = UDim2.fromOffset(420, 36)
	label.BackgroundColor3 = Config.Colors.HudBackground
	label.BackgroundTransparency = 0.4
	label.Font = Config.Ui.Font
	label.TextSize = 22
	label.TextColor3 = Config.Colors.Text
	Instance.new("UICorner").Parent = label
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	local function shouldSpectate(): boolean
		if not GAME_PHASES[GameState.getPhase()] then
			return false
		end
		return not (player:GetAttribute("InGame") and player:GetAttribute("Alive"))
	end

	-- Moves to the next (step 1) or previous (step -1) player still in.
	local function cycle(step: number)
		local list = alivePlayers()
		if #list == 0 then
			target = nil
			return
		end
		local index = if target then table.find(list, target) else nil
		if not index then
			target = list[1]
		else
			target = list[((index - 1 + step) % #list) + 1]
		end
	end

	local function stop()
		spectating = false
		target = nil
		gui.Enabled = false
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		ViewMode.apply()
	end

	RunService.RenderStepped:Connect(function()
		if not shouldSpectate() then
			if spectating then
				stop()
			end
			return
		end
		if not spectating then
			spectating = true
			gui.Enabled = true
			player.CameraMode = Enum.CameraMode.Classic -- spectate in third person
		end
		-- Keep watching someone who is still in (they may have been eliminated or left).
		if not target or not target.Parent or not target:GetAttribute("Alive") then
			cycle(1)
		end
		local character = target and target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
		label.Text = if target
			then `Spectating {target.DisplayName}  ·  Q / E to switch`
			else "Spectating"
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not spectating then
			return
		end
		local step = NEXT_KEYS[input.KeyCode]
		if step then
			cycle(step)
		end
	end)
end

return Spectate
