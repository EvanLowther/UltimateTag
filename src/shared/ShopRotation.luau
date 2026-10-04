--!strict
-- What the daily shop sells today. Picked from the day's number (shared/DayClock), so the server
-- and every client agree without asking, everyone sees the same shop, and it changes at
-- 00:00 UTC. Config.Shop: how many featured items, the deal's discount, and how likely each
-- rarity is to show up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local DayClock = require(Shared:WaitForChild("DayClock"))

local ShopRotation = {}

export type Offer = { id: string, price: number, deal: boolean }

-- Picks one item from `pool` weighted by Config.Shop.RarityWeights, and removes it.
local function pick(pool: { Catalog.Item }, rng: Random): Catalog.Item?
	local weights = Config.Shop.RarityWeights
	local total = 0
	for _, item in pool do
		total += weights[item.rarity] or 0
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for i, item in pool do
		roll -= weights[item.rarity] or 0
		if roll <= 0 then
			table.remove(pool, i)
			return item
		end
	end
	return table.remove(pool)
end

-- Today's offers: Config.Shop.Featured items at full price, then one deal at a discount.
function ShopRotation.today(day: number?): { Offer }
	local settings = Config.Shop
	local rng = Random.new((day or DayClock.day()) * 7919 + 17)
	local pool = {}
	for _, item in Catalog.Items do
		if item.shop then
			table.insert(pool, item)
		end
	end
	local offers: { Offer } = {}
	for i = 1, settings.Featured + 1 do
		local item = pick(pool, rng)
		if not item then
			break
		end
		local deal = i == settings.Featured + 1
		local price = Catalog.price(item)
		if deal then
			price = math.floor(price * (1 - settings.DealDiscount) / 5 + 0.5) * 5
		end
		table.insert(offers, { id = item.id, price = price, deal = deal })
	end
	return offers
end

-- Today's offer for an item, if it's in the shop.
function ShopRotation.offer(id: string): Offer?
	for _, offer in ShopRotation.today() do
		if offer.id == id then
			return offer
		end
	end
	return nil
end

return ShopRotation
