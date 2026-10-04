--!strict
-- Short on-screen messages ("You won 25 Coins!"). The server sends them with the Notify remote;
-- ProximityPrompts with a "Message" attribute (like the avatar shop's) show theirs when used.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Notify = {}

local SHOW_TIME = 3 -- seconds a message stays up

local label: TextLabel? = nil
local shownAt = 0

function Notify.show(text: string)
	local box = label
	if not box then
		return
	end
	box.Text = text
	box.Visible = true
	box.TextTransparency = 0
	box.BackgroundTransparency = 0.25
	local stamp = os.clock()
	shownAt = stamp
	task.delay(SHOW_TIME, function()
		if shownAt == stamp then
			local fade = TweenInfo.new(0.4)
			TweenService:Create(box, fade, { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
		end
	end)
end

function Notify.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notify"
	gui.ResetOnSpawn = false
	local box = Instance.new("TextLabel")
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -90)
	box.Size = UDim2.fromOffset(460, 44)
	box.BackgroundColor3 = Config.Colors.HudBackground
	box.BackgroundTransparency = 1
	box.Font = Config.Ui.Font
	box.TextSize = 26
	box.TextColor3 = Config.Colors.Text
	box.TextTransparency = 1
	box.Visible = false
	Instance.new("UICorner").Parent = box
	box.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	label = box

	Remotes.get("Notify").OnClientEvent:Connect(function(text: string)
		Notify.show(text)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local message = prompt:GetAttribute("Message")
		if typeof(message) == "string" then
			Notify.show(message)
		end
	end)
end

return Notify
