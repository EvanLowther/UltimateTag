--!strict
-- The leaderboard columns (Wins, Tags) shown in the player list. Wins are lifetime wins,
-- loaded and saved by WinsStore.
local Players = game:GetService("Players")

local STATS = { "Wins", "Tags" }

local Leaderstats = {}

local function setup(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in STATS do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
end

function Leaderstats.add(player: Player, stat: string, amount: number)
	local folder = player:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild(stat)
	if value and value:IsA("IntValue") then
		value.Value += amount
	end
end

function Leaderstats.set(player: Player, stat: string, amount: number)
	local folder = player:WaitForChild("leaderstats", 10)
	local value = folder and folder:FindFirstChild(stat)
	if value and value:IsA("IntValue") then
		value.Value = amount
	end
end

function Leaderstats.start()
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return Leaderstats
