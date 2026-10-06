--!strict
-- Cosmetics on the server: equipping (the Equip remote: an item id; only items you own) and
-- titles over heads. Each player's equipped items are also Player attributes (set by
-- server/PlayerData), which clients read for trails, tag effects and victories.
--   Titles: shared/TitleTag over each character's head, with their level and equipped title
--   (and its serial number for Iridescent ones), kept up to date when either changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Catalog)
local Remotes = require(Shared.Remotes)
local TitleTag = require(Shared.TitleTag)
local PlayerData = require(script.Parent.PlayerData)

local Cosmetics = {}

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
	if not head or not head:IsA("BasePart") then
		return
	end
	local id = player:GetAttribute("EquippedTitle") :: string?
	local item = Catalog.get(id)
	local profile = PlayerData.get(player)
	local serial = if profile and id then profile.Serials[id] else nil
	TitleTag.apply(head, item, (player:GetAttribute("Level") or 1) :: number, serial)
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
