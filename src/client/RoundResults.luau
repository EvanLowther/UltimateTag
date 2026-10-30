--!strict
-- The results card, in the Ui style. When a round ends the server sends RoundResults
-- (server/GameLoop): who went out and how (still It at the buzzer, fell, the train, AFK), how
-- many players are left, and your own numbers for the round (how you fared, your tags, your
-- time as It). The card shows for the Results phase (Config.Game.ResultsTime).
-- It is also the loading cover: when another round follows ("Next"), after `CoverAt` seconds a
-- full-screen dark backdrop fades in behind the card, so nobody sees the old map go and the
-- next one being built; it stays until the phase leaves Results (the next intro) and then
-- fades away. The new map's parts are preloaded while the cover is up. When the game is over
-- (no next round) there is no backdrop, and the card just goes when the phase changes.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(Shared:WaitForChild("GameState"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Ui = require(script.Parent.Menu.Ui)

local RoundResults = {}

type Out = { UserId: number, Name: string, DisplayName: string, Reason: string }
type Info = {
	Round: number,
	Left: number,
	Out: { Out },
	Next: boolean,
	Duration: number,
	CoverAt: number,
	Mine: { Fate: string, Reason: string?, Tags: number, Tagged: number, ItSeconds: number },
}

local COVER_FADE = 0.3 -- seconds the backdrop takes to fade in
local LEAVE_FADE = 0.45 -- seconds everything takes to fade out
local WIDTH = 440
local ROW = 30
local TAG_WIDTH = 120 -- the reason tag at the end of an out row
local CARD_FIXED = 330 -- the card's height without the out list
local MAX_LIST = 6 -- rows of the out list before it scrolls

local REASONS: { [string]: { text: string, color: Color3 } } = {
	It = { text = "STILL IT", color = Ui.Colors.Orange },
	Fell = { text = "FELL", color = Ui.Colors.Red },
	Train = { text = "THE TRAIN", color = Ui.Colors.Red },
	Afk = { text = "AFK", color = Ui.Colors.Dim },
}

local FATES: { [string]: { text: string, color: Color3 } } = {
	Safe = { text = "YOU'RE SAFE", color = Ui.Colors.Lime },
	Out = { text = "YOU'RE OUT", color = Ui.Colors.Red },
	Watching = { text = "WATCHING", color = Ui.Colors.Dim },
}

local screen: ScreenGui? = nil
local session = 0 -- counts cards, so late work from an earlier one gives up

-- A root frame that scales the card for the screen, like Menu's (Ui.scale), but on its own:
-- Ui.scale keeps the menu's one shared state, so it must not be called for a second gui.
local function scaledRoot(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local settings = Config.Ui
	local function update()
		local real = gui.AbsoluteSize
		if real.X <= 0 or real.Y <= 0 then
			local camera = workspace.CurrentCamera
			real = if camera then camera.ViewportSize else settings.Reference
		end
		local lowest = if Ui.touch() then settings.TouchMinScale else settings.MinScale
		local factor = math.clamp(
			math.min(real.X / settings.Reference.X, real.Y / settings.Reference.Y),
			lowest,
			settings.MaxScale
		)
		scale.Scale = factor
		root.Size = UDim2.fromScale(1 / factor, 1 / factor)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	return root
end

local function outRow(parent: Instance, order: number, entry: Out)
	local row = Ui.frame(parent)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW)
	local name = Ui.caps(row, entry.DisplayName, 17, Ui.Colors.Text)
	name.Size = UDim2.new(1, -TAG_WIDTH - 12, 1, 0) -- (a 20-letter name shrinks, then is cut off)
	name.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(name, 11, 17)
	local why = REASONS[entry.Reason] or REASONS.It
	local tag = Ui.slab(row, why.color, 6)
	tag.AnchorPoint = Vector2.new(1, 0.5)
	tag.Position = UDim2.fromScale(1, 0.5)
	tag.Size = UDim2.fromOffset(TAG_WIDTH, 24)
	local label = Ui.caps(tag, why.text, 13, Ui.Colors.Ink)
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 2
	Ui.pad(label, 12, 0)
	Ui.shrinkText(label, 11, 13)
	if why.color == Ui.Colors.Dim then
		label.TextColor3 = Ui.Colors.Text
	end
end

local function statLine(parent: Instance, order: number, title: string, value: string)
	local row = Ui.frame(parent)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 26)
	local left = Ui.caps(row, title, 14, Ui.Colors.Dim)
	left.Size = UDim2.new(0.6, -4, 1, 0)
	left.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(left, 11, 14)
	local right = Ui.caps(row, value, 16, Ui.Colors.Text)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.new(0.4, -4, 1, 0)
	right.TextXAlignment = Enum.TextXAlignment.Right
	Ui.shrinkText(right, 11, 16)
end

-- Fades a gui's whole tree out (frames, text, strokes), then destroys it.
local function fadeOut(gui: ScreenGui, backdrop: Frame?, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, item in gui:GetDescendants() do
		if item == backdrop then
			continue
		end
		if item:IsA("Frame") then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
		end
	end
	if backdrop then
		TweenService:Create(backdrop, info, { BackgroundTransparency = 1 }):Play()
	end
	task.delay(seconds + 0.05, function()
		gui:Destroy()
	end)
end

local function show(info: Info)
	session += 1
	local mine = session
	if screen then
		screen:Destroy()
		screen = nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoundResults"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30 -- over the HUD and menu, under the win screen
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen = gui

	-- The loading cover (straight in the gui: it covers the real screen).
	local backdrop = Ui.frame(gui, Color3.fromRGB(8, 8, 10))
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundTransparency = 1
	backdrop.ZIndex = 0
	backdrop.Active = info.Next -- (swallows clicks on the covered world)

	-- The card.
	local root = scaledRoot(gui)
	-- The list gets fewer rows (it scrolls) on a short screen, so the card always fits.
	local screenScale = root:FindFirstChildOfClass("UIScale")
	local camera = workspace.CurrentCamera
	local virtualHeight = if camera and screenScale
		then camera.ViewportSize.Y / math.max(screenScale.Scale, 0.01)
		else Config.Ui.Reference.Y
	local fitRows = math.floor((virtualHeight - 24 - CARD_FIXED) / ROW)
	local listRows = math.min(math.max(#info.Out, 1), math.max(1, math.min(MAX_LIST, fitRows)))
	local height = CARD_FIXED + listRows * ROW
	local card = Ui.panel(root, Ui.Colors.Panel, 16)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(
		if camera and screenScale
			then math.min(WIDTH, camera.ViewportSize.X / math.max(screenScale.Scale, 0.01) - 24)
			else WIDTH,
		height
	)
	card.ZIndex = 2
	Ui.popIn(card, 0.3)

	local header = Ui.slab(card, Ui.Colors.Cyan, 8)
	header.Position = UDim2.fromOffset(14, 14)
	header.Size = UDim2.new(1, -28, 0, 40)
	header.ZIndex = 3
	local title = Ui.title(header, `ROUND {info.Round} RESULTS`, 28, Ui.Colors.Ink)
	title.Size = UDim2.fromScale(1, 1)
	title.ZIndex = 4
	Ui.pad(title, 18, 2)
	Ui.shrinkText(title, 16, 28)

	local body = Ui.frame(card)
	body.ZIndex = 3
	body.Position = UDim2.fromOffset(28, 14 + 40 + 16)
	body.Size = UDim2.new(1, -56, 1, -(14 + 40 + 16 + 14))
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	local outTitle = Ui.caps(body, "WENT OUT", 13, Ui.Colors.Dim)
	outTitle.LayoutOrder = 1
	outTitle.Size = UDim2.new(1, 0, 0, 20)
	outTitle.TextXAlignment = Enum.TextXAlignment.Left

	local listHolder = Ui.frame(body)
	listHolder.LayoutOrder = 2
	listHolder.Size = UDim2.new(1, 0, 0, listRows * ROW)
	if #info.Out == 0 then
		local none = Ui.caps(listHolder, "NOBODY WAS ELIMINATED", 16, Ui.Colors.Dim)
		none.Size = UDim2.fromScale(1, 1)
		none.TextXAlignment = Enum.TextXAlignment.Left
	else
		local list = Ui.scroll(listHolder, 0)
		for i, entry in info.Out do
			outRow(list, i, entry)
		end
	end

	local left = Ui.frame(body)
	left.LayoutOrder = 3
	left.Size = UDim2.new(1, 0, 0, 50)
	local count = Ui.title(left, tostring(info.Left), 46, Ui.Colors.Yellow)
	count.Size = UDim2.new(0, 84, 1, 0)
	count.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(count, 24, 46)
	local leftText =
		Ui.caps(left, if info.Left == 1 then "PLAYER LEFT" else "PLAYERS LEFT", 18, Ui.Colors.Text)
	leftText.Position = UDim2.fromOffset(92, 0)
	leftText.Size = UDim2.new(1, -92, 1, 0)
	leftText.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(leftText, 11, 18)

	local you = Ui.caps(body, "YOUR ROUND", 13, Ui.Colors.Dim)
	you.LayoutOrder = 4
	you.Size = UDim2.new(1, 0, 0, 20)
	you.TextXAlignment = Enum.TextXAlignment.Left
	local fate = FATES[info.Mine.Fate] or FATES.Watching
	local fateText = fate.text
	local reason = info.Mine.Reason
	if info.Mine.Fate == "Out" and reason and REASONS[reason] then
		fateText = `YOU'RE OUT: {REASONS[reason].text}`
	end
	local fared = Ui.caps(body, fateText, 20, fate.color)
	fared.LayoutOrder = 5
	fared.Size = UDim2.new(1, 0, 0, 28)
	fared.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(fared, 11, 20)
	statLine(body, 6, "YOUR TAGS", tostring(info.Mine.Tags))
	statLine(body, 7, "TIME AS IT", Ui.clock(info.Mine.ItSeconds))

	local footer = Ui.caps(body, "", 14, Ui.Colors.Pink)
	footer.LayoutOrder = 8
	footer.Size = UDim2.new(1, 0, 0, 30)
	Ui.shrinkText(footer, 11, 14)
	local function refreshFooter()
		local seconds = GameState.getTimeLeft()
		footer.Text = if info.Next
			then `NEXT ROUND IN {math.max(seconds, 0)}`
			else "THE WINNER IS NEXT"
	end
	refreshFooter()
	local timerConnection = GameState.onChanged(refreshFooter)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- The cover comes up once the ELIMINATED moment is over.
	if info.Next then
		task.delay(info.CoverAt, function()
			if session == mine and backdrop.Parent then
				TweenService
					:Create(backdrop, TweenInfo.new(COVER_FADE), { BackgroundTransparency = 0 })
					:Play()
			end
		end)
	end

	-- It goes when the phase leaves Results (the next intro, the win screen, the dev panel).
	-- (The remote can arrive just before the phase change does, so the card waits to have seen
	-- Results first, and a timeout clears it if the phase never gets here.)
	local ended = false
	local sawResults = false
	local phaseConnection: RBXScriptConnection? = nil
	local function finish()
		if ended then
			return
		end
		ended = true
		timerConnection:Disconnect()
		if phaseConnection then
			phaseConnection:Disconnect()
		end
		if screen == gui then
			screen = nil
		end
		fadeOut(gui, backdrop, LEAVE_FADE)
	end
	local function maybeEnd()
		if ended or session ~= mine then
			return
		end
		if GameState.getPhase() == "Results" then
			sawResults = true
		elseif sawResults then
			finish()
		end
	end
	phaseConnection = GameState.onChanged(maybeEnd)
	maybeEnd()
	task.delay(info.Duration + Config.Game.ResultsLoadWait + 5, finish)
end

-- Shows a results card now (the UI auditor's worst case: a full list of long names).
function RoundResults.preview(info: Info)
	show(info)
end

-- Takes a previewed card away.
function RoundResults.hide()
	session += 1
	if screen then
		screen:Destroy()
		screen = nil
	end
end

function RoundResults.start()
	Remotes.get("RoundResults").OnClientEvent:Connect(show)

	-- Warm the next map while the cover is up: its parts and meshes are asked for now rather
	-- than as the intro starts.
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" and screen ~= nil then
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync(child:GetDescendants())
				end)
			end)
		end
	end)
end

return RoundResults
