--!strict
-- Cosmetics on the server: equipping (the Equip remote: a kind and an item id; only items you
-- own, of that kind) and titles over heads. Each player's equipped items are also Player
-- attributes (set by server/PlayerData), which clients read for trails, tag effects and
-- victories.
--   Titles: a BillboardGui over each character's head with their level and equipped title
--   (shared/Catalog look: Text, Color, Glow), kept up to date when either changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Catalog)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Cosmetics = {}

local TITLE_NAME = "TitleTag"

-- Equips an owned item (returns false if not allowed).
function Cosmetics.equip(player: Player, id: string): boolean
	local item = Catalog.get(id)
	local profile = PlayerData.get(player)
	if not item or not profile or not profile.Owned[id] then
		return false
	end
	PlayerData.update(player, function(p)
		p.Equipped[item.kind] = id
	end)
	return true
end

-- Builds (or refreshes) the title over a character's head.
local function showTitle(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local item = Catalog.get(player:GetAttribute("EquippedTitle") :: string?)
	local level = player:GetAttribute("Level") or 1
	local gui = head:FindFirstChild(TITLE_NAME) :: BillboardGui?
	if not gui then
		local new = Instance.new("BillboardGui")
		new.Name = TITLE_NAME
		new.Size = UDim2.fromOffset(220, 44)
		new.StudsOffset = Vector3.new(0, 2.9, 0)
		new.MaxDistance = 90
		new.AlwaysOnTop = false
		new.LightInfluence = 0
		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "Level"
		levelLabel.BackgroundTransparency = 1
		levelLabel.Size = UDim2.fromScale(1, 0.42)
		levelLabel.Font = Enum.Font.FredokaOne
		levelLabel.TextScaled = true
		levelLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
		levelLabel.TextStrokeTransparency = 0.4
		levelLabel.Parent = new
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.BackgroundTransparency = 1
		titleLabel.Position = UDim2.fromScale(0, 0.42)
		titleLabel.Size = UDim2.fromScale(1, 0.58)
		titleLabel.Font = Enum.Font.LuckiestGuy
		titleLabel.TextScaled = true
		titleLabel.TextStrokeTransparency = 0.2
		titleLabel.Parent = new
		new.Parent = head
		gui = new
	end
	local billboard = gui :: BillboardGui
	local levelLabel = billboard:FindFirstChild("Level") :: TextLabel
	local titleLabel = billboard:FindFirstChild("Title") :: TextLabel
	levelLabel.Text = `Lv {level}`
	if item then
		titleLabel.Text = item.look.Text
		titleLabel.TextColor3 = item.look.Color
		titleLabel.TextStrokeColor3 = if item.look.Glow
			then item.look.Color:Lerp(Color3.new(1, 1, 1), 0.6)
			else Color3.new(0, 0, 0)
		titleLabel.TextStrokeTransparency = if item.look.Glow then 0.5 else 0.2
	else
		titleLabel.Text = ""
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		showTitle(player)
	end)
	player:GetAttributeChangedSignal("EquippedTitle"):Connect(function()
		showTitle(player)
	end)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		showTitle(player)
	end)
	if player.Character then
		task.spawn(showTitle, player)
	end
end

function Cosmetics.start()
	Remotes.get("Equip").OnServerEvent:Connect(function(player, id)
		if type(id) == "string" then
			Cosmetics.equip(player, id)
		end
	end)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Cosmetics
