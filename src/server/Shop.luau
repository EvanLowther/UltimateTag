--!strict
-- The shop on the server.
--   ShopBuy (an item id): buys one of today's offers (shared/ShopRotation) if you have the
--   coins and don't own it yet.
--   OpenCrate: uses one of your free crates if you have any, otherwise costs
--   Config.Shop.CratePrice. Rolls a rarity by Catalog.Rarities weights (Common 60%, Rare 28%,
--   Epic 10%, Legendary 2%, shown in the shop), then a crate item of that rarity. A duplicate
--   pays back Config.Shop.DuplicateRefund of its price. The result goes to the client (the
--   Reward remote, Kind "Crate") for the opening animation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ShopRotation = require(Shared.ShopRotation)
local PlayerData = require(script.Parent.PlayerData)

local Shop = {}

local busy: { [Player]: boolean } = {} -- one purchase at a time per player

local function tell(player: Player, text: string)
	Remotes.get("Notify"):FireClient(player, text)
end

local function buy(player: Player, id: string)
	local offer = ShopRotation.offer(id)
	local profile = PlayerData.get(player)
	local item = Catalog.get(id)
	if not offer or not profile or not item then
		tell(player, "That isn't in the shop today")
		return
	end
	if profile.Owned[id] then
		tell(player, "You already own that")
		return
	end
	if profile.Coins < offer.price then
		tell(player, "Not enough coins")
		return
	end
	PlayerData.update(player, function(p)
		p.Coins -= offer.price
		p.Owned[id] = true
	end)
	Remotes.get("Reward")
		:FireClient(player, { Kind = "Grant", Reason = "Purchased!", Items = { id } })
end

-- Rolls a rarity by the crate odds, then an item of it.
local function roll(): Catalog.Item?
	local total = 0
	for name, rarity in Catalog.Rarities do
		if name ~= "Exclusive" then
			total += rarity.weight
		end
	end
	local pick = math.random() * total
	local chosen = "Common"
	for name, rarity in Catalog.Rarities do
		if name ~= "Exclusive" then
			pick -= rarity.weight
			if pick <= 0 then
				chosen = name
				break
			end
		end
	end
	local pool = {}
	for _, item in Catalog.Items do
		if item.crate and item.rarity == chosen then
			table.insert(pool, item)
		end
	end
	return if #pool > 0 then pool[math.random(#pool)] else nil
end

local function openCrate(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local free = profile.Crates > 0
	if not free and profile.Coins < Config.Shop.CratePrice then
		tell(player, "Not enough coins")
		return
	end
	local item = roll()
	if not item then
		return
	end
	local duplicate = profile.Owned[item.id] == true
	local refund = if duplicate
		then math.floor(Catalog.price(item) * Config.Shop.DuplicateRefund)
		else 0
	PlayerData.update(player, function(p)
		if free then
			p.Crates -= 1
		else
			p.Coins -= Config.Shop.CratePrice
		end
		if duplicate then
			p.Coins += refund
		else
			p.Owned[item.id] = true
		end
	end)
	Remotes.get("Reward"):FireClient(player, {
		Kind = "Crate",
		Item = item.id,
		Duplicate = duplicate,
		Refund = refund,
	})
end

function Shop.start()
	Remotes.get("ShopBuy").OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" or busy[player] then
			return
		end
		busy[player] = true
		buy(player, id)
		busy[player] = nil
	end)
	Remotes.get("OpenCrate").OnServerEvent:Connect(function(player)
		if busy[player] then
			return
		end
		busy[player] = true
		openCrate(player)
		task.wait(0.5) -- a short gap so a held click can't open a pile of crates at once
		busy[player] = nil
	end)
end

return Shop
