--!strict
-- Who can play: real players, and bots (server/Bots) that fill small games. A bot is an
-- ObjectValue in ReplicatedStorage.Bots: its Name is the bot's name, its Value is its character,
-- and it carries the same attributes a player does (Role, InGame, Alive, Spectating...) plus
-- DisplayName and UserId (negative, so it never matches a real player). So code that only reads
-- attributes works on either, and a bot can be sent through a remote like a Player. These helpers
-- cover the rest (the character, the names, finding one), on the server and every client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contestant = {}

export type Contestant = any -- a Player, or a bot's ObjectValue

Contestant.FolderName = "Bots"

-- The folder the bots live in (nil until the server has made it).
function Contestant.folder(): Instance?
	return ReplicatedStorage:FindFirstChild(Contestant.FolderName)
end

function Contestant.isBot(contestant: Contestant): boolean
	return typeof(contestant) == "Instance" and contestant:IsA("ObjectValue")
end

-- Every bot there is right now.
function Contestant.bots(): { Contestant }
	local folder = Contestant.folder()
	local list = {}
	if folder then
		for _, bot in folder:GetChildren() do
			if bot:IsA("ObjectValue") then
				table.insert(list, bot)
			end
		end
	end
	return list
end

-- Every player, then every bot.
function Contestant.all(): { Contestant }
	local list: { Contestant } = Players:GetPlayers()
	for _, bot in Contestant.bots() do
		table.insert(list, bot)
	end
	return list
end

function Contestant.character(contestant: Contestant): Model?
	if Contestant.isBot(contestant) then
		local value = contestant.Value
		return if value and value:IsA("Model") then value else nil
	end
	return contestant.Character
end

function Contestant.displayName(contestant: Contestant): string
	if Contestant.isBot(contestant) then
		return contestant:GetAttribute("DisplayName") or contestant.Name
	end
	return contestant.DisplayName
end

function Contestant.userId(contestant: Contestant): number
	if Contestant.isBot(contestant) then
		return contestant:GetAttribute("UserId") or 0
	end
	return contestant.UserId
end

-- Still here (a player in the server, a bot not removed)?
function Contestant.present(contestant: Contestant): boolean
	return contestant ~= nil and contestant.Parent ~= nil
end

function Contestant.byUserId(userId: number): Contestant?
	if userId > 0 then
		return Players:GetPlayerByUserId(userId)
	end
	for _, bot in Contestant.bots() do
		if bot:GetAttribute("UserId") == userId then
			return bot
		end
	end
	return nil
end

-- Whose character this is (a player's or a bot's).
function Contestant.fromCharacter(character: Instance?): Contestant?
	if not character then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return player
	end
	for _, bot in Contestant.bots() do
		if bot.Value == character then
			return bot
		end
	end
	return nil
end

return Contestant
