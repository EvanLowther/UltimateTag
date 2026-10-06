--!strict
-- The shop and crates on the server.
--   ShopBuy (an item id): buys one of today's offers (shared/ShopRotation) if you have the
--   coins and don't own it yet.
--   BuyCrate: costs Config.Shop.CratePrice and adds a Mystery crate to the player's crates.
--   OpenCrate (count): opens that many of the player's crates (bought, or earned from levels,
--   the streak and the wheel; up to Config.Shop.OpenAllMax at once) from the Rewards window.
--   Each one rolls a rarity by the crate odds (shared/Catalog: Common 45%, Rare 30%, Epic 15%,
--   Legendary 9.95%, Iridescent 0.05%, shown in the Shop and Rewards), then an item of it.
--   Duplicates are possible and pay nothing back. A new Iridescent item gets its serial number
--   (server/Serials) and the whole server hears about it (the Announce remote). The results go
--   to the client (the Reward remote, Kind "Crate") for the opening reel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ShopRotation = require(Shared.ShopRotation)
local PlayerData = require(script.Parent.PlayerData)
local Serials = require(script.Parent.Serials)

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

-- Buys a crate: it goes into the player's crates (opened from the Rewards window).
local function buyCrate(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if profile.Coins < Config.Shop.CratePrice then
		tell(player, "Not enough coins")
		return
	end
	PlayerData.update(player, function(p)
		p.Coins -= Config.Shop.CratePrice
		p.Crates += 1
	end)
	tell(player, "Crate bought! Open it in Rewards")
end

-- Opens up to `count` of the player's crates.
local function openCrates(player: Player, count: number)
	local profile = PlayerData.get(player)
	if not profile or profile.Crates <= 0 then
		tell(player, "You don't have any crates")
		return
	end
	count = math.clamp(math.floor(count), 1, math.min(profile.Crates, Config.Shop.OpenAllMax))
	local results = {}
	local seen: { [string]: boolean } = {}
	for _ = 1, count do
		local item = Catalog.roll()
		if item then
			local duplicate = profile.Owned[item.id] == true or seen[item.id] == true
			seen[item.id] = true
			table.insert(results, { Item = item.id, Duplicate = duplicate })
		end
	end
	if #results == 0 then
		return
	end
	-- New Iridescent items take their serial numbers (yields: saved first).
	for _, result in results do
		local item = Catalog.get(result.Item) :: Catalog.Item
		if item.rarity == "Iridescent" and not result.Duplicate then
			result.Serial = Serials.next(item.id)
		end
	end
	PlayerData.update(player, function(p)
		p.Crates = math.max(0, p.Crates - count)
		for _, result in results do
			p.Owned[result.Item] = true
			if result.Serial and not p.Serials[result.Item] then
				p.Serials[result.Item] = result.Serial
			end
		end
	end)
	Remotes.get("Reward"):FireClient(player, { Kind = "Crate", Items = results })
	for _, result in results do
		if result.Serial then
			Remotes.get("Announce"):FireAllClients({
				Kind = "Unbox",
				Name = player.DisplayName,
				Item = result.Item,
				Serial = result.Serial,
			})
		end
	end
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
	Remotes.get("BuyCrate").OnServerEvent:Connect(function(player)
		if busy[player] then
			return
		end
		busy[player] = true
		buyCrate(player)
		busy[player] = nil
	end)
	Remotes.get("OpenCrate").OnServerEvent:Connect(function(player, count)
		if busy[player] then
			return
		end
		busy[player] = true
		openCrates(player, if type(count) == "number" and count == count then count else 1)
		task.wait(0.5) -- a short gap so a held click can't open a pile of crates at once
		busy[player] = nil
	end)
end

return Shop
