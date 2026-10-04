--!strict
-- Robux purchases, ready but switched off: everything here only runs once Config.Monetization
-- has IDs (create the gamepasses and developer products on the Roblox website first).
--   VIP gamepass: +VipXPBonus XP and the exclusive VIP title. Sets the VIP attribute.
--   2x Coins gamepass: double coins from games. Sets the DoubleCoins attribute.
--   Coin packs (developer products): coins, granted once per receipt.
-- server/Progression reads the VIP and DoubleCoins attributes.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)

local Purchases = {}

local function owns(player: Player, passId: number?): boolean
	if not passId then
		return false
	end
	local ok, result =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and result == true
end

local function checkPasses(player: Player)
	local settings = Config.Monetization
	if owns(player, settings.VipPass) then
		player:SetAttribute("VIP", true)
		Progression.grant(player, { Items = { "title_vip" } }, nil)
	end
	if owns(player, settings.DoubleCoinsPass) then
		player:SetAttribute("DoubleCoins", true)
	end
end

function Purchases.start()
	local settings = Config.Monetization
	local anything = settings.VipPass or settings.DoubleCoinsPass or next(settings.CoinPacks) ~= nil
	if not anything then
		return
	end
	PlayerData.onLoaded(function(player)
		checkPasses(player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if bought and (passId == settings.VipPass or passId == settings.DoubleCoinsPass) then
			checkPasses(player)
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local coins = settings.CoinPacks[receipt.ProductId]
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not coins or not player or not PlayerData.get(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local already = false
		PlayerData.update(player, function(profile)
			profile.Receipts = profile.Receipts or {}
			if profile.Receipts[receipt.PurchaseId] then
				already = true
				return
			end
			profile.Receipts[receipt.PurchaseId] = true
			profile.Coins += coins
		end)
		if not already then
			Progression.grant(player, {}, `+{coins} coins. Thank you!`)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Purchases
