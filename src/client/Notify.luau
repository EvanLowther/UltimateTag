--!strict
-- Short on-screen messages ("You won 25 Coins!"). The server sends them with the Notify remote;
-- ProximityPrompts with a "Message" attribute (like the avatar shop's) show theirs when used.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Ui = require(script.Parent.Menu.Ui)

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
	box.BackgroundTransparency = 0
	local stroke = box:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	local stamp = os.clock()
	shownAt = stamp
	task.delay(SHOW_TIME, function()
		if shownAt == stamp then
			local fade = TweenInfo.new(0.4)
			TweenService:Create(box, fade, { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
			local outline = box:FindFirstChildOfClass("UIStroke")
			if outline then
				TweenService:Create(outline, fade, { Transparency = 1 }):Play()
			end
		end
	end)
end

function Notify.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notify"
	gui.ResetOnSpawn = false
	-- A white pill with a thick outline, above the money and level bar.
	local box = Instance.new("TextLabel")
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -96)
	box.Size = UDim2.fromOffset(0, 44)
	box.AutomaticSize = Enum.AutomaticSize.X
	box.BackgroundColor3 = Ui.Colors.Window
	box.BackgroundTransparency = 1
	box.Font = Ui.Font
	box.TextSize = 24
	box.TextColor3 = Ui.Colors.Ink
	box.TextTransparency = 1
	box.Visible = false
	Ui.corner(box, 22)
	Ui.padding(box, 0)
	local pad = box:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingLeft = UDim.new(0, 18)
		pad.PaddingRight = UDim.new(0, 18)
	end
	Ui.outline(box, 3)
	box.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	label = box

	Remotes.get("Notify").OnClientEvent:Connect(function(text: string)
		Notify.show(text)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local message = prompt:GetAttribute("Message")
		-- The Avatar Shop prompt opens the shop now (client/Menu), no message.
		if
			typeof(message) == "string" and not CollectionService:HasTag(prompt, "AvatarShopPrompt")
		then
			Notify.show(message)
		end
	end)
end

return Notify
