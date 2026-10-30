--!strict
-- Menu, Leaders page: two tabs.
--   Leaderboards: the top players (server/Leaderboards) by Wins, Tags, Level or Wall runs, all
--   time or this week: a podium for the top 3, a list under it, and your own rank pinned at the
--   bottom. The boards come from the server through the Leaderboard remote when the page opens.
--   My stats: your numbers from your profile (wins, games, win rate, level, tags, rounds
--   survived, best win streak, time played) and your moves.
-- Both pages scroll, so nothing is cut off on a short window; under NARROW_BELOW (a phone held
-- upright) the chips use two rows and the stat tiles two columns (Ui.bodySize).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Profile = require(script.Parent.Parent.Profile)
local Ui = require(script.Parent.Ui)

local LeadersTab = {}

local PODIUM_COLORS = {
	Color3.fromRGB(255, 214, 10), -- 1st
	Color3.fromRGB(192, 198, 207), -- 2nd
	Color3.fromRGB(217, 136, 74), -- 3rd
}
local PERIODS = { "All time", "This week" }
local NARROW_BELOW = 560 -- pages narrower than this (virtual pixels) get the narrow layout
local SCROLL_PAD = 12 -- the scroll lists' padding on the right
local FOOTER = 64 -- room kept under the list for your rank and the footer line

-- Puts a player's headshot on an ImageLabel (Roblox's thumbnail URL loads it in the background).
local function headshot(image: ImageLabel, userId: number)
	image.Image = `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local function avatar(parent: Instance, userId: number?, size: number, ring: Color3): ImageLabel
	local image = Instance.new("ImageLabel")
	image.BackgroundColor3 = Ui.Colors.Tab
	image.BorderSizePixel = 0
	image.Size = UDim2.fromOffset(size, size)
	local border = Instance.new("UIStroke")
	border.Color = ring
	border.Thickness = 2
	border.Parent = image
	if userId and userId > 0 then
		headshot(image, userId)
	end
	image.Parent = parent
	return image
end

function LeadersTab.build(page: Frame, api: { [string]: any }): () -> ()
	local player = Players.LocalPlayer
	local boardDefs = {}
	for _, def in Config.Leaderboards.Boards do
		if def.Menu ~= false then -- (Coins is only on the lobby's board)
			table.insert(boardDefs, def)
		end
	end

	local top = Ui.hit(30) + 12 -- under the Leaderboards / My stats tabs
	local chipHeight = Ui.hit(24)
	local function narrow(): boolean
		return Ui.bodySize(page).X < NARROW_BELOW
	end

	-- Leaderboards.
	local boardsFrame = Ui.frame(page)
	boardsFrame.Position = UDim2.fromOffset(0, top)
	boardsFrame.Size = UDim2.new(1, 0, 1, -top)

	local boardId = boardDefs[1].Id
	local period = PERIODS[1]
	local data: { [string]: any }? = nil
	local redraw: () -> ()

	local boardNames = {}
	local nameToId: { [string]: string } = {}
	for _, def in boardDefs do
		table.insert(boardNames, def.Name)
		nameToId[def.Name] = def.Id
	end
	local boardChips, selectBoard = Ui.tabs(boardsFrame, boardNames, Ui.Colors.Text, function(name)
		boardId = nameToId[name]
		redraw()
	end, 24, 11, 9)
	boardChips.Position = UDim2.fromOffset(0, 0)
	local periodChips, selectPeriod = Ui.tabs(boardsFrame, PERIODS, Ui.Colors.Text, function(name)
		period = name
		redraw()
	end, 24, 11, 9)
	selectBoard(boardDefs[1].Name)
	selectPeriod(period)

	-- The podium and the list scroll together between the chips and your own rank.
	local middle = Ui.scroll(boardsFrame, 4)
	local podium: Frame
	local list = middle

	-- The period chips sit at the right of the board chips, or under them when narrow.
	local function arrangeChips()
		local second = narrow()
		if second then
			periodChips.AnchorPoint = Vector2.zero
			periodChips.Position = UDim2.fromOffset(0, chipHeight + 6)
		else
			periodChips.AnchorPoint = Vector2.new(1, 0)
			periodChips.Position = UDim2.fromScale(1, 0)
		end
		local chipsBottom = if second then chipHeight * 2 + 6 else chipHeight
		middle.Position = UDim2.fromOffset(0, chipsBottom + 10)
		middle.Size = UDim2.new(1, 0, 1, -(chipsBottom + 10 + FOOTER))
	end
	arrangeChips()
	local mine = Ui.frame(boardsFrame)
	mine.AnchorPoint = Vector2.new(0, 1)
	mine.Position = UDim2.new(0, 0, 1, -22)
	mine.Size = UDim2.new(1, 0, 0, 36)
	local footer = Ui.caps(boardsFrame, "", 11, Ui.Colors.Dim)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, 18)

	local function listRow(
		order: number,
		rank: string,
		userId: number?,
		name: string,
		value: string,
		highlight: boolean
	)
		local parent = if highlight then mine else list
		local r = Ui.slab(parent, if highlight then Ui.Colors.Orange else Ui.Colors.Card, 6)
		r.LayoutOrder = if highlight then order else 10 + order -- (after the podium)
		r.Size = if highlight then UDim2.fromScale(1, 1) else UDim2.new(1, -6, 0, 30)
		local text = if highlight then Ui.Colors.Ink else Ui.Colors.Text
		local rankLabel = Ui.caps(r, rank, 14, if highlight then Ui.Colors.Ink else Ui.Colors.Dim)
		rankLabel.Position = UDim2.fromOffset(14, 0)
		rankLabel.Size = UDim2.new(0, 52, 1, 0)
		rankLabel.TextXAlignment = Enum.TextXAlignment.Left
		local face = avatar(
			r,
			userId,
			if highlight then 26 else 22,
			if highlight then Ui.Colors.Ink else Ui.Colors.Tab
		)
		face.AnchorPoint = Vector2.new(0, 0.5)
		face.Position = UDim2.new(0, 70, 0.5, 0)
		local nameLabel = Ui.caps(r, name, 13, text)
		nameLabel.Position = UDim2.fromOffset(104, 0)
		nameLabel.Size = UDim2.new(1, -220, 1, 0)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		local valueLabel = Ui.caps(r, value, 14, text)
		valueLabel.AnchorPoint = Vector2.new(1, 0)
		valueLabel.Position = UDim2.new(1, -16, 0, 0)
		valueLabel.Size = UDim2.new(0, 110, 1, 0)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	end

	local function podiumBlock(rank: number, entry: { [string]: any }?, x: number, height: number)
		local column = Ui.frame(podium)
		column.AnchorPoint = Vector2.new(0.5, 1)
		column.Position = UDim2.fromScale(x, 1)
		-- Three columns side by side: 170 wide each, less on a narrow page.
		local available = Ui.bodySize(page).X - SCROLL_PAD - 6
		column.Size = UDim2.fromOffset(math.min(170, math.floor(available * 0.31)), 156)
		local color = PODIUM_COLORS[rank]
		local block = Ui.slab(column, color, 10)
		block.AnchorPoint = Vector2.new(0.5, 1)
		block.Position = UDim2.fromScale(0.5, 1)
		block.Size = UDim2.new(1, -16, 0, height)
		local number = Ui.title(block, tostring(rank), if rank == 1 then 34 else 28, Ui.Colors.Ink)
		number.Size = UDim2.new(1, 0, 0, height * 0.6)
		local value =
			Ui.caps(block, if entry then Ui.number(entry.Value) else "-", 13, Ui.Colors.Ink)
		value.Position = UDim2.fromOffset(0, height * 0.55)
		value.Size = UDim2.new(1, 0, 0, 18)
		local nameLabel =
			Ui.caps(column, if entry then entry.Name or "?" else "-", 13, Ui.Colors.Text)
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.new(0.5, 0, 1, -height - 4)
		nameLabel.Size = UDim2.new(1, 0, 0, 16)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		local face =
			avatar(column, if entry then entry.UserId else nil, if rank == 1 then 44 else 38, color)
		face.AnchorPoint = Vector2.new(0.5, 1)
		face.Position = UDim2.new(0.5, 0, 1, -height - 24)
		if rank == 1 then
			local crown = Ui.icon(column, "crown", 28, Ui.Colors.Yellow, Ui.Colors.Ink)
			crown.AnchorPoint = Vector2.new(0.5, 1)
			crown.Position = UDim2.new(0.5, 0, 1, -height - 70)
		end
	end

	redraw = function()
		local def = nil
		for _, d in boardDefs do
			if d.Id == boardId then
				def = d
			end
		end
		arrangeChips()
		periodChips.Visible = def ~= nil and def.Weekly == true
		local weekly = period == "This week" and def ~= nil and def.Weekly == true
		local key = `{boardId}:{if weekly then "Week" else "All"}`
		Ui.clear(list)
		Ui.clear(mine)
		podium = Ui.frame(middle)
		podium.LayoutOrder = 1
		podium.Size = UDim2.new(1, -6, 0, 156)
		if not data then
			footer.Text = "LOADING..."
			return
		end
		local entries = (data.Boards and data.Boards[key]) or {}
		podiumBlock(2, entries[2], 0.2, 58)
		podiumBlock(1, entries[1], 0.5, 82)
		podiumBlock(3, entries[3], 0.8, 44)
		if #entries == 0 then
			-- Nothing recorded yet (a new week, or saving is off and nobody has a score).
			local none = Ui.caps(list, "No scores yet", 12, Ui.Colors.Dim)
			none.LayoutOrder = 10
			none.Size = UDim2.new(1, -6, 0, 30)
		end
		for i = 4, math.min(#entries, Config.Leaderboards.ShowCount) do
			local entry = entries[i]
			listRow(i, `#{i}`, entry.UserId, entry.Name or "?", Ui.number(entry.Value), false)
		end
		local me = data.Me and data.Me[key]
		local rank = if me and me.Rank then `#{me.Rank}` else `{Config.Leaderboards.TopCount}+`
		listRow(0, rank, player.UserId, "You", Ui.number(if me then me.Value else 0), true)
		footer.Text = if data.Source ~= "global"
			then "SAVING IS OFF: SHOWING THIS SERVER'S PLAYERS"
			elseif weekly then Ui.upper(
				`Resets in {DayClock.format(DayClock.secondsToNextWeek())}`
			)
			else "ALL-TIME"
	end

	Remotes.get("Leaderboard").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			data = payload
			redraw()
		end
	end)

	-- My stats.
	local statsFrame = Ui.frame(page)
	statsFrame.Position = boardsFrame.Position
	statsFrame.Size = boardsFrame.Size
	statsFrame.Visible = false
	local statsScroll = Ui.scroll(statsFrame, 8)
	local tiles = Ui.frame(statsScroll)
	tiles.LayoutOrder = 1
	tiles.Size = UDim2.new(1, 0, 0, 152)
	local tileGrid = Instance.new("UIGridLayout")
	tileGrid.CellSize = UDim2.new(0.25, -6, 0, 72)
	tileGrid.CellPadding = UDim2.fromOffset(8, 8)
	tileGrid.SortOrder = Enum.SortOrder.LayoutOrder
	tileGrid.Parent = tiles
	local movesTitle = Ui.caps(statsScroll, "Moves", 13, Ui.Colors.Text)
	movesTitle.LayoutOrder = 2
	movesTitle.Size = UDim2.new(1, 0, 0, 20)
	movesTitle.TextXAlignment = Enum.TextXAlignment.Left
	local moves = Ui.frame(statsScroll)
	moves.LayoutOrder = 3
	moves.Size = UDim2.new(1, 0, 0, 64)

	local function drawStats()
		local profile = Profile.get()
		if not profile then
			return
		end
		local stats = profile.Stats
		-- Four tiles across, or two on a narrow page.
		local columns = if narrow() then 2 else 4
		local rows = math.ceil(8 / columns)
		tileGrid.CellSize = UDim2.new(1 / columns, -(8 * (columns - 1)) / columns, 0, 72)
		tiles.Size = UDim2.new(1, 0, 0, rows * 72 + (rows - 1) * 8)
		Ui.clear(tiles)
		local games = math.max(stats.GamesPlayed, 0)
		local minutes = stats.PlayMinutes or 0
		local tileList = {
			{ "Wins", Ui.number(stats.Wins), Ui.Colors.Yellow },
			{ "Games played", Ui.number(games), Ui.Colors.Text },
			{
				"Win rate",
				if games > 0 then `{math.floor(stats.Wins / games * 100 + 0.5)}%` else "-",
				Ui.Colors.Lime,
			},
			{ "Level", tostring(profile.Level), Ui.Colors.Cyan },
			{ "Tags", Ui.number(stats.Tags), Ui.Colors.Pink },
			{ "Rounds survived", Ui.number(stats.RoundsSurvived), Ui.Colors.Text },
			{ "Best win streak", tostring(stats.BestWinStreak), Ui.Colors.Orange },
			{ "Time played", `{minutes // 60}h {minutes % 60}m`, Ui.Colors.Text },
		}
		for i, tile in tileList do
			local card = Ui.panel(tiles, Ui.Colors.Card, 8)
			card.LayoutOrder = i
			local strip = Ui.frame(card, tile[3])
			strip.Size = UDim2.new(1, -8, 0, 4)
			local label = Ui.caps(card, tile[1], 11, Ui.Colors.Dim)
			label.Position = UDim2.fromOffset(10, 10)
			label.Size = UDim2.new(1, -20, 0, 14)
			label.TextXAlignment = Enum.TextXAlignment.Left
			local value = Ui.title(card, tile[2], 30, tile[3])
			value.Position = UDim2.fromOffset(10, 26)
			value.Size = UDim2.new(1, -20, 0, 36)
			value.TextXAlignment = Enum.TextXAlignment.Left
			Ui.shrinkText(value, 16, 30)
			Ui.shrinkText(label, 8, 11)
		end
		Ui.clear(moves)
		local moveList = {
			{ "wall", "Wall runs", stats.WallRuns, Ui.Colors.Cyan },
			{ "speed", "Slides", stats.Slides, Ui.Colors.Pink },
		}
		local most = 1
		for _, move in moveList do
			most = math.max(most, move[3])
		end
		for i, move in moveList do
			local y = (i - 1) * 30
			local icon = Ui.icon(moves, move[1], 22, move[4], Ui.Colors.Text)
			icon.Position = UDim2.fromOffset(2, y + 1)
			local name = Ui.caps(moves, move[2], 12, Ui.Colors.Text)
			name.Position = UDim2.fromOffset(32, y)
			name.Size = UDim2.fromOffset(100, 24)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local bar, set = Ui.bar(moves, move[4], 4)
			bar.Position = UDim2.fromOffset(136, y + 6)
			bar.Size = UDim2.new(1, -136 - 80, 0, 12)
			set(move[3] / most)
			local value = Ui.caps(moves, Ui.number(move[3]), 13, Ui.Colors.Text)
			value.AnchorPoint = Vector2.new(1, 0)
			value.Position = UDim2.new(1, 0, 0, y)
			value.Size = UDim2.fromOffset(70, 24)
			value.TextXAlignment = Enum.TextXAlignment.Right
		end
	end

	local current = "Leaderboards"
	local selectTab: (string) -> ()
	local _, select = Ui.tabs(page, { "Leaderboards", "My stats" }, Ui.Colors.Orange, function(name)
		current = name
		boardsFrame.Visible = name == "Leaderboards"
		statsFrame.Visible = name == "My stats"
		selectTab(name)
		if name == "My stats" then
			drawStats()
		else
			api.send("Leaderboard")
			redraw()
		end
	end)
	selectTab = select
	selectTab(current)
	redraw()

	return function()
		if current == "My stats" then
			drawStats()
		else
			redraw()
		end
	end
end

-- Ask for fresh boards whenever the page opens.
function LeadersTab.opened()
	Remotes.get("Leaderboard"):FireServer()
end

return LeadersTab
