--!strict
-- Keeps the lobby leaderboard screen up to date: the top lifetime wins (WinsStore), every
-- Config.Lobby.LeaderboardRefresh seconds. The screen is the part tagged "LobbyLeaderboard"
-- (made by tools/SetupLobby); its SurfaceGui has a "List" of rows named Row1, Row2... each with
-- "Rank", "Player" and "Wins" labels, and a "Footer" label.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WinsStore = require(script.Parent.WinsStore)

local LobbyLeaderboard = {}

local TAG = "LobbyLeaderboard"

local function setText(parent: Instance?, name: string, text: string)
	local label = parent and parent:FindFirstChild(name)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function fill(screen: Instance, entries: { WinsStore.Entry }, source: string)
	local gui = screen:FindFirstChildOfClass("SurfaceGui")
	local list = gui and gui:FindFirstChild("List")
	if not gui or not list then
		return
	end
	for i = 1, Config.Lobby.LeaderboardRows do
		local row = list:FindFirstChild(`Row{i}`)
		local entry = entries[i]
		setText(row, "Rank", `#{i}`)
		setText(row, "Player", if entry then entry.name else "—")
		setText(row, "Wins", if entry then tostring(entry.wins) else "")
	end
	setText(
		gui,
		"Footer",
		if source == "global" then "All-time wins" else "This server (saving is off)"
	)
end

local function refresh()
	local screens = CollectionService:GetTagged(TAG)
	if #screens == 0 then
		return
	end
	local entries, source = WinsStore.top(Config.Lobby.LeaderboardRows)
	for _, screen in screens do
		fill(screen, entries, source)
	end
end

function LobbyLeaderboard.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function()
		task.defer(refresh)
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(Config.Lobby.LeaderboardRefresh)
		end
	end)
end

return LobbyLeaderboard
