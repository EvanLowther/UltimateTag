--!strict
-- The three boards on the lobby's leaderboard wall (tools/lobby_layout.py builds them; their text
-- parts carry Board, Row and Field attributes, row 0 being the footer):
--   GLOBAL   GLOBAL LEADERS: all-time wins (WinsStore), every Config.Lobby.BoardRefresh seconds.
--   SESSION  THIS SESSION: the players in this server by the wins and tags they've had since they
--            joined, every Config.Lobby.SessionRefresh seconds.
--   RICHEST  RICHEST PLAYERS: the most coins (server/Leaderboards' Coins board), every
--            BoardRefresh seconds.
-- Without data stores the GLOBAL and RICHEST boards list this server's players, and their
-- footers say so.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Leaderboards = require(script.Parent.Leaderboards)
local Progression = require(script.Parent.Progression)
local WinsStore = require(script.Parent.WinsStore)

local LobbyBoards = {}

type Row = { name: string, values: { [string]: string } }

local labels: { [string]: { [number]: { [string]: TextLabel } } } = {} -- board, row, field
local session: { [Player]: { wins: number, tags: number } } = {}

-- 1284 -> "1,284"
local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = string.reverse(text):gsub("(%d%d%d)", "%1,")
	out = string.reverse(out)
	return if string.sub(out, 1, 1) == "," then string.sub(out, 2) else out
end

local function collect()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	for _, item in lobby:GetDescendants() do
		local board, row, field =
			item:GetAttribute("Board"), item:GetAttribute("Row"), item:GetAttribute("Field")
		if type(board) ~= "string" or type(row) ~= "number" or type(field) ~= "string" then
			continue
		end
		local label = item:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			labels[board] = labels[board] or {}
			labels[board][row] = labels[board][row] or {}
			labels[board][row][field] = label
		end
	end
end

-- Puts rows (and the footer) on a board; rows past the list are left blank.
local function show(board: string, rows: { Row }, footer: string)
	for row, fields in labels[board] or {} do
		if row == 0 then
			if fields.Footer then
				fields.Footer.Text = footer
			end
			continue
		end
		local entry = rows[row]
		for field, label in fields do
			label.Text = if not entry
				then ""
				elseif field == "Name" then entry.name
				else entry.values[field] or ""
		end
	end
end

local function savedFooter(source: string): string
	return if source == "global"
		then `UPDATES EVERY {Config.Lobby.BoardRefresh}s`
		else "THIS SERVER ONLY: SAVING IS OFF"
end

local function showGlobal()
	local entries, source = WinsStore.top(Config.Lobby.BoardRows)
	local rows: { Row } = {}
	for i, entry in entries do
		rows[i] = { name = entry.name, values = { Value = commas(entry.wins) } }
	end
	show("GLOBAL", rows, savedFooter(source))
end

local function showRichest()
	local entries, source = Leaderboards.top("Coins")
	local rows: { Row } = {}
	for i = 1, math.min(#entries, Config.Lobby.BoardRows) do
		local entry = entries[i]
		rows[i] = {
			name = entry.Name or `Player {entry.UserId}`,
			values = { Value = commas(entry.Value) },
		}
	end
	show("RICHEST", rows, savedFooter(source))
end

local function showSession()
	local list = {}
	for player, counts in session do
		if player.Parent then
			table.insert(list, { name = player.Name, wins = counts.wins, tags = counts.tags })
		end
	end
	table.sort(list, function(a, b)
		if a.wins ~= b.wins then
			return a.wins > b.wins
		elseif a.tags ~= b.tags then
			return a.tags > b.tags
		end
		return a.name < b.name
	end)
	local rows: { Row } = {}
	for i = 1, math.min(#list, Config.Lobby.BoardRows) do
		local item = list[i]
		rows[i] = {
			name = item.name,
			values = { Wins = tostring(item.wins), Tags = tostring(item.tags) },
		}
	end
	show("SESSION", rows, "RESETS WHEN THIS SERVER CLOSES")
end

function LobbyBoards.start()
	collect()
	local function join(player: Player)
		session[player] = { wins = 0, tags = 0 }
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		session[player] = nil
	end)
	Progression.onRecord(function(player, event, amount)
		local counts = session[player]
		if not counts then
			return
		elseif event == "Win" then
			counts.wins += amount
		elseif event == "Tag" then
			counts.tags += amount
		end
	end)

	task.spawn(function()
		while true do
			showSession()
			task.wait(Config.Lobby.SessionRefresh)
		end
	end)
	task.spawn(function()
		while true do
			showGlobal()
			showRichest()
			task.wait(Config.Lobby.BoardRefresh)
		end
	end)
end

return LobbyBoards
