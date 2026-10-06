--!strict
-- Menu, Locker page (docked at the left of the screen): your cosmetics by kind (Trails, Tags,
-- Titles, Victories; shared/Catalog), rarest first, as tiles. Owned ones can be equipped; the
-- rest show how to get them. Picking a tile shows it on a copy of your character in the 3D
-- preview (client/LockerStage), with an info plate on the right: the rarity and kind, the
-- name, what it looks like, the Equip button (or how to get it), and the serial number of an
-- Iridescent you own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))
local LockerStage = require(script.Parent.Parent.LockerStage)
local Profile = require(script.Parent.Parent.Profile)
local ItemCard = require(script.Parent.ItemCard)
local Ui = require(script.Parent.Ui)

local LockerTab = {}

LockerTab.docked = true

local KINDS = { "Trail", "TagEffect", "Title", "Victory" }
local SCENES = {
	Trail = "Running",
	TagEffect = "Tagging a dummy",
	Title = "Tagging a dummy",
	Victory = "Victory",
}

local plate: Frame? = nil
local chip: Frame? = nil
local show: (() -> ())? = nil -- redraws the plate and the preview for the selection

-- The header's right side: how much you own.
function LockerTab.info(profile: { [string]: any }): string
	local owned, total = 0, 0
	for _, item in Catalog.Items do
		total += 1
		if profile.Owned[item.id] then
			owned += 1
		end
	end
	return `{owned} / {total} owned`
end

-- How to get an item you don't have.
local function source(item: Catalog.Item): string
	if item.note then
		return item.note
	elseif item.rarity == "Iridescent" then
		return `Crates only: {Catalog.Rarities.Iridescent.weight}%`
	elseif ShopRotation.offer(item.id) then
		return "In the shop today"
	end
	return "From crates or the shop"
end

function LockerTab.opened()
	if plate then
		plate.Visible = true
	end
	if chip then
		chip.Visible = true
	end
	LockerStage.open()
	if show then
		show()
	end
end

function LockerTab.closed()
	if plate then
		plate.Visible = false
	end
	if chip then
		chip.Visible = false
	end
	LockerStage.close()
end

function LockerTab.build(page: Frame, api: { [string]: any }): () -> ()
	local kind = "Trail"
	local selected: { [string]: string } = {} -- kind -> item id

	local tabNames = {}
	local nameToKind: { [string]: string } = {}
	for _, k in KINDS do
		local name = Catalog.KindNames[k]
		table.insert(tabNames, name)
		nameToKind[name] = k
	end
	local refresh: () -> ()
	local _, selectTab = Ui.tabs(page, tabNames, Ui.Colors.Cyan, function(name)
		kind = nameToKind[name]
		refresh()
	end, 28, 11)

	local count = Ui.caps(page, "", 11, Ui.Colors.Dim)
	count.Position = UDim2.fromOffset(2, 34)
	count.Size = UDim2.new(1, -4, 0, 16)
	count.TextXAlignment = Enum.TextXAlignment.Left

	local holder = Ui.frame(page)
	holder.Position = UDim2.fromOffset(0, 56)
	holder.Size = UDim2.new(1, 0, 1, -56)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Ui.Colors.Dim
	scroll.Parent = holder
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / 3, -6, 0, 76)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = scroll

	-- The info plate (top right of the screen) and the preview chip (bottom right).
	local info = Ui.panel(api.gui, Ui.Colors.Panel, 12)
	info.Name = "LockerInfo"
	info.AnchorPoint = Vector2.new(1, 0)
	info.Position = UDim2.new(1, -16, 0, 16)
	info.Size = UDim2.fromOffset(310, 168)
	info.Visible = false
	plate = info
	local infoRarity = Ui.frame(info)
	infoRarity.Position = UDim2.fromOffset(14, 12)
	infoRarity.Size = UDim2.new(1, -28, 0, 16)
	local infoName = Ui.title(info, "", 34, Ui.Colors.Text)
	infoName.Position = UDim2.fromOffset(14, 28)
	infoName.Size = UDim2.new(1, -28, 0, 38)
	infoName.TextXAlignment = Enum.TextXAlignment.Left
	infoName.TextTruncate = Enum.TextTruncate.AtEnd
	local infoText = Ui.text(info, "", 13, Ui.Colors.Dim)
	infoText.Position = UDim2.fromOffset(14, 66)
	infoText.Size = UDim2.new(1, -28, 0, 36)
	infoText.TextXAlignment = Enum.TextXAlignment.Left
	infoText.TextYAlignment = Enum.TextYAlignment.Top
	infoText.TextWrapped = true
	local action = Ui.frame(info)
	action.Position = UDim2.fromOffset(14, 112)
	action.Size = UDim2.new(1, -28, 0, 36)
	local serial = Ui.caps(info, "", 12, Ui.Colors.Text)
	serial.AnchorPoint = Vector2.new(1, 0)
	serial.Position = UDim2.new(1, -16, 0, 12)
	serial.Size = UDim2.fromOffset(100, 16)
	serial.TextXAlignment = Enum.TextXAlignment.Right
	Ui.holo(serial)

	local scene = Ui.slab(api.gui, Ui.Colors.Panel, 8)
	scene.Name = "LockerScene"
	scene.AnchorPoint = Vector2.new(1, 1)
	scene.Position = UDim2.new(1, -16, 1, -16)
	scene.Size = UDim2.fromOffset(300, 28)
	scene.Visible = false
	chip = scene
	local sceneText = Ui.caps(scene, "", 12, Ui.Colors.Yellow)
	sceneText.Size = UDim2.fromScale(1, 1)

	local function current(profile: { [string]: any }): Catalog.Item?
		local id = selected[kind] or profile.Equipped[kind]
		return Catalog.get(id)
	end

	local function drawPlate()
		local profile = Profile.get()
		if not profile then
			return
		end
		local item = current(profile)
		Ui.clear(infoRarity)
		Ui.clear(action)
		if not item then
			infoName.Text = ""
			infoText.Text = ""
			serial.Text = ""
			return
		end
		local line = ItemCard.rarityLine(infoRarity, item, 12)
		line.Size = UDim2.fromScale(1, 1)
		infoName.Text = item.name
		infoText.Text = Catalog.describe(item)
		local owned = profile.Owned[item.id] == true
		local equipped = profile.Equipped[item.kind] == item.id
		local number = profile.Serials[item.id]
		serial.Text = if owned and number then `NO. {number}` else ""
		if equipped then
			local done = Ui.button(
				action,
				"✓ Equipped",
				Ui.Colors.Tab,
				function() end,
				Ui.Colors.Cyan
			)
			done.Size = UDim2.fromOffset(150, 34)
		elseif owned then
			local equip = Ui.button(action, "Equip", Ui.Colors.Cyan, function()
				api.send("Equip", item.id)
			end)
			equip.Size = UDim2.fromOffset(150, 34)
			Ui.setTextSize(equip, 17)
		else
			local how = Ui.button(action, `🔒 {source(item)}`, Ui.Colors.Tab, function()
				if ShopRotation.offer(item.id) then
					api.open("Shop")
				end
			end, Ui.Colors.Dim)
			how.Size = UDim2.new(1, 0, 0, 34)
			Ui.setTextSize(how, 13)
		end
		local live = LockerStage.isActive()
		sceneText.Text = if live
			then Ui.upper(`▶ {SCENES[item.kind]} · your character`)
			else "PREVIEW IN THE LOBBY"
		sceneText.TextColor3 = if live then Ui.Colors.Yellow else Ui.Colors.Pink
		if live then
			LockerStage.show(item)
		end
	end
	show = drawPlate

	refresh = function()
		local profile = Profile.get()
		if not profile then
			return
		end
		selectTab(Catalog.KindNames[kind])
		local items = {}
		local owned = 0
		for _, item in Catalog.Items do
			if item.kind == kind then
				table.insert(items, item)
				if profile.Owned[item.id] then
					owned += 1
				end
			end
		end
		count.Text = Ui.upper(`{owned} / {#items} owned · rarest first`)
		table.sort(items, function(a, b)
			local ra, rb = Catalog.Rarities[a.rarity].order, Catalog.Rarities[b.rarity].order
			if ra ~= rb then
				return ra > rb
			end
			local oa, ob = profile.Owned[a.id] == true, profile.Owned[b.id] == true
			if oa ~= ob then
				return oa
			end
			return a.name < b.name
		end)
		local chosen = current(profile)
		Ui.clear(scroll)
		for i, item in items do
			local tile = ItemCard.tile(
				scroll,
				item,
				profile.Owned[item.id] == true,
				profile.Equipped[item.kind] == item.id,
				chosen ~= nil and chosen.id == item.id,
				function()
					selected[kind] = item.id
					refresh()
				end
			)
			tile.LayoutOrder = i
		end
		if kind == "Victory" then
			local note = Ui.caps(
				scroll,
				"Victories come in Epic, Legendary and Iridescent only",
				11,
				Ui.Colors.Dim
			)
			note.LayoutOrder = #items + 1
			note.TextWrapped = true
		end
		if plate and plate.Visible then
			drawPlate()
		end
	end
	return refresh
end

return LockerTab
