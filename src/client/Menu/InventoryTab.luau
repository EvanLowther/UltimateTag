--!strict
-- Menu, Inventory tab: every cosmetic by kind (Trails, Tag Effects, Titles, Victories). Owned
-- ones can be equipped (and effects tried out on yourself); ones you don't have are greyed out
-- with how to get them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local CosmeticEffects = require(script.Parent.Parent.CosmeticEffects)
local Profile = require(script.Parent.Parent.Profile)
local ItemCard = require(script.Parent.ItemCard)
local Ui = require(script.Parent.Ui)

local InventoryTab = {}

function InventoryTab.build(page: Frame, api: { [string]: any }): () -> ()
	local kind = "Trail"

	local kinds = Instance.new("Frame")
	kinds.BackgroundTransparency = 1
	kinds.Size = UDim2.new(1, 0, 0, 38)
	kinds.Parent = page
	local kindLayout = Instance.new("UIListLayout")
	kindLayout.FillDirection = Enum.FillDirection.Horizontal
	kindLayout.Padding = UDim.new(0, 8)
	kindLayout.Parent = kinds

	local count = Ui.label(page, "", 16, Ui.Colors.Dim)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, 0, 0, 8)
	count.Size = UDim2.fromOffset(120, 22)
	count.TextXAlignment = Enum.TextXAlignment.Right

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 46)
	scroll.Size = UDim2.new(1, 0, 1, -46)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = page
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(ItemCard.Width, ItemCard.Height)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = scroll

	local refresh: () -> ()

	local kindButtons: { [string]: TextButton } = {}
	for _, k in Catalog.Kinds do
		local button = Ui.button(kinds, Catalog.KindNames[k], Ui.Colors.PanelLight, function()
			kind = k
			refresh()
		end)
		button.Size = UDim2.fromOffset(118, 34)
		button.TextSize = 17
		kindButtons[k] = button
	end

	refresh = function()
		local profile = Profile.get()
		if not profile then
			return
		end
		for k, button in kindButtons do
			button.BackgroundColor3 = if k == kind then Ui.Colors.Accent else Ui.Colors.PanelLight
		end
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local items = {}
		local owned = 0
		local total = 0
		for _, item in Catalog.Items do
			if item.kind == kind then
				table.insert(items, item)
				total += 1
				if profile.Owned[item.id] then
					owned += 1
				end
			end
		end
		count.Text = `{owned} / {total} owned`
		-- Owned first, then by rarity.
		table.sort(items, function(a, b)
			local ownA, ownB = profile.Owned[a.id] == true, profile.Owned[b.id] == true
			if ownA ~= ownB then
				return ownA
			end
			return Catalog.Rarities[a.rarity].order < Catalog.Rarities[b.rarity].order
		end)
		for i, item in items do
			local has = profile.Owned[item.id] == true
			local card, bottom = ItemCard.make(scroll, item, not has)
			card.LayoutOrder = i
			if has then
				local equipped = profile.Equipped[item.kind] == item.id
				local canTry = item.kind == "TagEffect" or item.kind == "Victory"
				local equip = Ui.button(
					bottom,
					if equipped then "Equipped" else "Equip",
					if equipped then Ui.Colors.Good else Ui.Colors.Accent,
					function()
						if not equipped then
							api.send("Equip", item.id)
						end
					end
				)
				equip.Size = UDim2.new(if canTry then 0.62 else 1, 0, 0, 34)
				equip.TextSize = 16
				if canTry then
					local try = Ui.button(bottom, "Try", Ui.Colors.PanelLight, function()
						CosmeticEffects.preview(item.id)
					end)
					try.AnchorPoint = Vector2.new(1, 0)
					try.Position = UDim2.fromScale(1, 0)
					try.Size = UDim2.new(0.34, 0, 0, 34)
					try.TextSize = 15
				end
			else
				local how = if item.note then item.note else "Shop or crates"
				local label = Ui.label(bottom, `🔒 {how}`, 13, Ui.Colors.Dim)
				label.Size = UDim2.new(1, 0, 0, 40)
				label.TextWrapped = true
				label.ZIndex = 4
			end
		end
	end
	return refresh
end

return InventoryTab
