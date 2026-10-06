--!strict
-- Short on-screen messages ("You won 25 Coins!"). The server sends them with the Notify remote;
-- ProximityPrompts with a "Message" attribute (like the avatar shop's) show theirs when used.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	local toast = box.Parent :: Frame
	box.Text = Ui.upper(text)
	toast.Visible = true
	Ui.fade(toast, 0.05)
	box.TextTransparency = 0
	local stamp = os.clock()
	shownAt = stamp
	task.delay(SHOW_TIME, function()
		if shownAt == stamp then
			toast.Visible = false
		end
	end)
end

function Notify.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notify"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- A black slanted toast with a yellow edge, above the level bar.
	local toast = Ui.slab(gui, Ui.Colors.Panel, 10)
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -70)
	toast.Size = UDim2.fromOffset(0, 40)
	toast.Visible = false
	local edge = Ui.slab(toast, Ui.Colors.Yellow, 10)
	edge.Size = UDim2.new(0, 18, 1, 0)
	edge.ZIndex = 2
	local box = Ui.caps(toast, "", 16, Ui.Colors.Text)
	box.Size = UDim2.fromScale(0, 1)
	box.AutomaticSize = Enum.AutomaticSize.X
	box.ZIndex = 3
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 30)
	pad.PaddingRight = UDim.new(0, 22)
	pad.Parent = box
	Ui.fitWidth(toast, box)
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
