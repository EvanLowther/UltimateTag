--!strict
-- Menu, Inventory tab: every cosmetic by kind (Trails, Tag Effects, Titles, Victories) as bright
-- cards. Owned ones can be equipped (and effects tried on yourself); ones you don't have are
-- dimmed with how to get them. The Crates section opens the crates you've bought or earned.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local CosmeticEffects = require(script.Parent.Parent.CosmeticEffects)
local Profile = require(script.Parent.Parent.Profile)
local ItemCard = require(script.Parent.ItemCard)
local Ui = require(script.Parent.Ui)

local InventoryTab = {}

local KIND_COLORS = {
	Trail = Ui.Colors.Blue,
	TagEffect = Ui.Colors.Red,
	Title = Ui.Colors.Orange,
	Victory = Ui.Colors.Purple,
	Crates = Ui.Colors.Teal,
}
local KIND_NAMES = {
	Trail = "Trails",
	TagEffect = "Tags",
	Title = "Titles",
	Victory = "Victories",
	Crates = "Crates",
}

-- A red "!" on the button while you have crates to open.
function InventoryTab.badge(profile: { [string]: any }): boolean
	return profile.Crates > 0
end

function InventoryTab.build(page: Frame, api: { [string]: any }): () -> ()
	local kind = "Trail"

	local kinds = Instance.new("Frame")
	kinds.BackgroundTransparency = 1
	kinds.Size = UDim2.new(1, 0, 0, 40)
	kinds.Parent = page
	local kindLayout = Instance.new("UIListLayout")
	kindLayout.FillDirection = Enum.FillDirection.Horizontal
	kindLayout.Padding = UDim.new(0, 8)
	kindLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	kindLayout.Parent = kinds

	local count = Ui.ink(page, "", 17, Ui.Colors.InkDim)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -4, 0, 44)
	count.Size = UDim2.fromOffset(160, 20)
	count.TextXAlignment = Enum.TextXAlignment.Right

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 66)
	holder.Size = UDim2.new(1, 0, 1, -66)
	holder.Parent = page
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Ui.Colors.Outline
	scroll.Parent = holder
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(ItemCard.Width, ItemCard.Height)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = scroll

	local refresh: () -> ()

	local kindButtons: { [string]: TextButton } = {}
	local kindList = table.clone(Catalog.Kinds)
	table.insert(kindList, "Crates")
	for _, k in kindList do
		local button = Ui.button(kinds, KIND_NAMES[k], KIND_COLORS[k], function()
			kind = k
			refresh()
		end)
		button.Size = UDim2.fromOffset(104, 36)
		Ui.setTextSize(button, 16)
		kindButtons[k] = button
	end

	-- The crates panel (shown instead of the grid in the Crates section).
	local cratePanel = Ui.card(holder, Ui.Colors.Teal, 14)
	cratePanel.Size = UDim2.new(1, -12, 0, 150)
	cratePanel.Position = UDim2.fromOffset(6, 6)
	cratePanel.Visible = false
	local crateIcon = Instance.new("TextLabel")
	crateIcon.BackgroundTransparency = 1
	crateIcon.Text = "📦"
	crateIcon.TextScaled = true
	crateIcon.Rotation = -8
	crateIcon.Position = UDim2.fromOffset(14, 14)
	crateIcon.Size = UDim2.fromOffset(120, 120)
	crateIcon.Parent = cratePanel
	local crateCount = Ui.text(cratePanel, "", 30)
	crateCount.Position = UDim2.fromOffset(148, 16)
	crateCount.Size = UDim2.new(1, -310, 0, 36)
	crateCount.TextXAlignment = Enum.TextXAlignment.Left
	local odds = {}
	for _, name in { "Common", "Rare", "Epic", "Legendary" } do
		local rarity = Catalog.Rarities[name]
		table.insert(odds, `<font color="#{rarity.color:ToHex()}">{name} {rarity.weight}%</font>`)
	end
	local crateOdds = Ui.text(cratePanel, table.concat(odds, "  "), 15, nil, Ui.Font)
	crateOdds.Position = UDim2.fromOffset(148, 58)
	crateOdds.Size = UDim2.new(1, -310, 0, 20)
	crateOdds.TextXAlignment = Enum.TextXAlignment.Left
	local crateNote =
		Ui.text(cratePanel, "Duplicates are possible. Buy more in the Shop.", 14, nil, Ui.Font)
	crateNote.Position = UDim2.fromOffset(148, 82)
	crateNote.Size = UDim2.new(1, -310, 0, 20)
	crateNote.TextXAlignment = Enum.TextXAlignment.Left
	local openButton = Ui.button(cratePanel, "OPEN", Ui.Colors.Green, function()
		api.send("OpenCrate")
	end)
	openButton.AnchorPoint = Vector2.new(1, 0.5)
	openButton.Position = UDim2.new(1, -16, 0.5, 0)
	openButton.Size = UDim2.fromOffset(140, 70)
	Ui.setTextSize(openButton, 28)

	refresh = function()
		local profile = Profile.get()
		if not profile then
			return
		end
		for k, button in kindButtons do
			button.BackgroundColor3 = if k == kind then KIND_COLORS[k] else Ui.Colors.Locked
		end
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local crates = kind == "Crates"
		cratePanel.Visible = crates
		scroll.Visible = not crates
		if crates then
			crateCount.Text =
				`YOU HAVE {profile.Crates} CRATE{if profile.Crates == 1 then "" else "S"}`
			openButton.BackgroundColor3 = if profile.Crates > 0
				then Ui.Colors.Green
				else Ui.Colors.Locked
			count.Text = ""
			return
		end
		local items = {}
		local owned, total = 0, 0
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
					if equipped then "ON" else "EQUIP",
					if equipped then Ui.Colors.Green else Ui.Colors.Yellow,
					function()
						if not equipped then
							api.send("Equip", item.id)
						end
					end
				)
				equip.Size = UDim2.new(if canTry then 0.6 else 1, 0, 0, 38)
				Ui.setTextSize(equip, 17)
				if canTry then
					local try = Ui.button(bottom, "TRY", Ui.Colors.Blue, function()
						CosmeticEffects.preview(item.id)
					end)
					try.AnchorPoint = Vector2.new(1, 0)
					try.Position = UDim2.fromScale(1, 0)
					try.Size = UDim2.new(0.36, 0, 0, 38)
					Ui.setTextSize(try, 15)
				end
			else
				local how = if item.note then item.note else "Shop or crates"
				local label = Ui.text(bottom, `🔒 {how}`, 13, nil, Ui.Font)
				label.Size = UDim2.new(1, 0, 0, 42)
				label.TextWrapped = true
				label.ZIndex = 4
			end
		end
	end
	return refresh
end

return InventoryTab
