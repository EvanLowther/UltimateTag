--!strict
-- One-time lobby setup, for after importing the lobby model into Studio. Lives in
-- ServerStorage.Tools; it never runs in a game.
--
--   1. Studio: Home (or Avatar) tab > Import 3D > pick assets_src/lobby/UltimateTagLobby.fbx >
--      Import (default settings are fine).
--   2. Command bar (View > Command Bar), run:
--        require(game.ServerStorage.Tools.SetupLobby)()
--   3. Save the place (Ctrl+S). The lobby now lives in the place file; Rojo doesn't touch it.
--
-- What it does:
--   * Finds the import by its marker cubes and fixes its scale, rotation and position (the
--     island's center goes to Config.Lobby.Position), then deletes the markers.
--   * Organizes every piece into Workspace.Lobby/<Category>/<Object> Models, each with its pivot
--     at its base, so a palm or bench is one click to move, rotate or duplicate.
--   * Sets collision per object (none for decorations, simple boxes or hulls for the rest), makes
--     *_Glow parts Neon, and makes the ocean see-through.
--   * Adds the working parts: sign text (editable SurfaceGuis), the live leaderboard screen,
--     bench and chair Seats, palm trunk colliders, the shop and reward wheel ProximityPrompts,
--     the reward wheel's spin data, the lobby SpawnLocation and an invisible boundary ring.
-- Running it again on a fresh import replaces the old lobby. Ctrl+Z undoes it.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Data = require(script.Parent.LobbyData) :: any

type Vec = { number }

-- Blender (x, y, z) to Roblox: Blender's Z is up and its -Y (the island's front) is Roblox's -Z.
local function dir(v: Vec): Vector3
	return Vector3.new(-v[1], v[3], v[2])
end

local origin = Vector3.zero -- the island's center once placed

local function point(v: Vec): Vector3
	return origin + dir(v)
end

local function rgb(v: Vec): Color3
	return Color3.new(v[1], v[2], v[3])
end

local FIDELITY = {
	Box = Enum.CollisionFidelity.Box,
	Hull = Enum.CollisionFidelity.Hull,
	Precise = Enum.CollisionFidelity.PreciseConvexDecomposition,
}

-- Text styles.
local DARK_BROWN = Color3.fromRGB(70, 40, 20)
local CREAM = Color3.fromRGB(245, 228, 190)
local NAVY = Color3.fromRGB(20, 32, 70)
local GOLD = Color3.fromRGB(255, 205, 60)
local WHITE = Color3.new(1, 1, 1)

-- The imported model: the one holding the marker cubes.
local function findImport(): Instance?
	for _, child in workspace:GetChildren() do
		if child:FindFirstChild("Marker_O", true) then
			return child
		end
	end
	return nil
end

local function findPart(root: Instance, name: string): BasePart?
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function markers(root: Instance): (Vector3, Vector3, Vector3)
	local o = findPart(root, "Marker_O")
	local x = findPart(root, "Marker_X")
	local y = findPart(root, "Marker_Y")
	assert(o and x and y, "[SetupLobby] the import is missing its marker cubes")
	return o.Position, x.Position, y.Position
end

-- Scales, turns and moves the import so Blender's layout lands right at Config.Lobby.Position.
local function place(model: Model)
	local o, x, y = markers(model)
	local scale = (x - o).Magnitude / 100
	if math.abs(scale - 1) > 0.01 then
		model:ScaleTo(model:GetScale() / scale)
		o, x, y = markers(model)
	end
	local ex, ey = (x - o).Unit, (y - o).Unit
	local ez = ex:Cross(ey)
	local zMarker = findPart(model, "Marker_Z")
	if zMarker and (zMarker.Position - o):Dot(ez) < 0 then
		warn(
			"[SetupLobby] The import came in mirrored; the layout will be flipped. Re-import with default settings."
		)
	end
	local dx, dy, dz = dir({ 1, 0, 0 }), dir({ 0, 1, 0 }), dir({ 0, 0, 1 })
	local function rotate(v: Vector3): Vector3
		return dx * ex:Dot(v) + dy * ey:Dot(v) + dz * ez:Dot(v)
	end
	local rotation = CFrame.fromMatrix(
		Vector3.zero,
		rotate(Vector3.xAxis),
		rotate(Vector3.yAxis),
		rotate(Vector3.zAxis)
	)
	model:PivotTo(CFrame.new(o) * rotation * CFrame.new(-o) * model:GetPivot())
	o = markers(model)
	model:PivotTo(CFrame.new(Config.Lobby.Position - o) * model:GetPivot())
	origin = Config.Lobby.Position
end

local function invisible(part: BasePart, collide: boolean)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = collide
	part.CanTouch = collide
	part.CanQuery = collide
	part.CastShadow = false
end

-- Collision, material and glow for one imported piece.
local function configure(part: BasePart, collision: string)
	part.Anchored = true
	part.CastShadow = true
	local glow = Data.Glow[part.Name]
	if glow then
		part.Material = Enum.Material.Neon
		part.Color = rgb(glow.Color)
		part.Transparency = glow.Transparency
		if part:IsA("MeshPart") then
			part.TextureID = ""
		end
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
		return
	end
	part.Material = Enum.Material.SmoothPlastic
	if collision == "None" then
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	else
		part.CanCollide, part.CanTouch, part.CanQuery = true, true, true
		if part:IsA("MeshPart") then
			part.CollisionFidelity = FIDELITY[collision] or Enum.CollisionFidelity.Hull
		end
	end
	if part.Name == "Ocean" then
		part.Transparency = 0.22
		part.Reflectance = 0.05
		part.CastShadow = false
	elseif part.Name == "Shoreline_Foam" then
		part.Transparency = 0.3
		part.CastShadow = false
	elseif part.Name == "Seabed" then
		part.CastShadow = false
	end
end

-- Moves every listed piece into Lobby/<Category>/<Object> Models. Returns the Models by name.
local function organize(import: Instance, lobby: Model): { [string]: Model }
	local folders: { [string]: Folder } = {}
	local models: { [string]: Model } = {}
	for _, object in Data.Objects do
		local model = Instance.new("Model")
		model.Name = object.Name
		for _, partName in object.Parts do
			local part = findPart(import, partName)
			if part then
				part.Parent = model
				configure(part, object.Collision)
				if not model.PrimaryPart then
					model.PrimaryPart = part
				end
			else
				warn(`[SetupLobby] missing piece {partName}`)
			end
		end
		if not model.PrimaryPart then
			model:Destroy()
			continue
		end
		model.WorldPivot = CFrame.new(point(object.Pivot))
			* CFrame.Angles(0, math.rad(object.Yaw), 0)
		local folder = folders[object.Category]
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = object.Category
			folder.Parent = lobby
			folders[object.Category] = folder
		end
		model.Parent = folder
		models[object.Name] = model
	end
	return models
end

-- Text -----------------------------------------------------------------------------------------
local function label(
	parent: Instance,
	name: string,
	text: string,
	font: Enum.Font,
	color: Color3,
	y: number,
	height: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, height)
	l.Font = font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.Parent = parent
	return l
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local function surface(part: BasePart, light: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = light
	gui.Parent = part
	return gui
end

-- Two lines stacked: the first takes `split` of the height.
local function twoLines(
	gui: SurfaceGui,
	lines: { string },
	split: number,
	fonts: { Enum.Font },
	colors: { Color3 }
): { TextLabel }
	local out = {}
	if #lines == 1 then
		table.insert(out, label(gui, "Line1", lines[1], fonts[1], colors[1], 0.05, 0.9))
	else
		table.insert(out, label(gui, "Line1", lines[1], fonts[1], colors[1], 0.02, split - 0.04))
		table.insert(
			out,
			label(
				gui,
				"Line2",
				lines[2],
				fonts[2] or fonts[1],
				colors[2] or colors[1],
				split,
				1 - split - 0.02
			)
		)
	end
	return out
end

local function leaderboardScreen(gui: SurfaceGui)
	local rows = Config.Lobby.LeaderboardRows
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 0.88)
	list.Parent = gui
	for i = 1, rows do
		local row = Instance.new("Frame")
		row.Name = `Row{i}`
		row.Position = UDim2.new(0.02, 0, (i - 1) / rows, 2)
		row.Size = UDim2.new(0.96, 0, 1 / rows, -4)
		row.BackgroundColor3 = if i % 2 == 1
			then Color3.fromRGB(38, 62, 130)
			else Color3.fromRGB(28, 46, 100)
		Instance.new("UICorner").Parent = row
		row.Parent = list
		local rank = label(
			row,
			"Rank",
			`#{i}`,
			Enum.Font.FredokaOne,
			if i <= 3 then GOLD else WHITE,
			0.1,
			0.8
		)
		rank.Size = UDim2.fromScale(0.14, 0.8)
		rank.Position = UDim2.fromScale(0.02, 0.1)
		local who = label(row, "Player", "—", Enum.Font.FredokaOne, WHITE, 0.1, 0.8)
		who.Size = UDim2.fromScale(0.58, 0.8)
		who.Position = UDim2.fromScale(0.18, 0.1)
		who.TextXAlignment = Enum.TextXAlignment.Left
		local wins = label(row, "Wins", "", Enum.Font.FredokaOne, GOLD, 0.1, 0.8)
		wins.Size = UDim2.fromScale(0.2, 0.8)
		wins.Position = UDim2.fromScale(0.78, 0.1)
		wins.TextXAlignment = Enum.TextXAlignment.Right
	end
	local footer = label(
		gui,
		"Footer",
		"Loading...",
		Enum.Font.FredokaOne,
		Color3.fromRGB(170, 190, 230),
		0.89,
		0.1
	)
	footer.Name = "Footer"
end

local function addPanel(panel: any, models: { [string]: Model })
	local owner = models[panel.Owner]
	if not owner then
		warn(`[SetupLobby] no object {panel.Owner} for panel {panel.Name}`)
		return
	end
	local part = Instance.new("Part")
	part.Name = panel.Name
	part.Size = Vector3.new(panel.Size[1], panel.Size[2], 0.05)
	invisible(part, false)
	local center, normal, up = point(panel.Center), dir(panel.Normal), dir(panel.Up)
	part.CFrame = CFrame.lookAt(center + normal * 0.08, center + normal * 1.08, up)
	part.Parent = owner
	local kind, lines = panel.Kind, panel.Lines
	if kind == "Welcome" then
		local gui = surface(part, 0)
		local labels = twoLines(
			gui,
			lines,
			0.34,
			{ Enum.Font.FredokaOne, Enum.Font.LuckiestGuy },
			{ WHITE, WHITE }
		)
		stroke(labels[1], DARK_BROWN, 4)
		stroke(labels[2], Color3.fromRGB(90, 40, 10), 6)
		local gradient = Instance.new("UIGradient")
		gradient.Color =
			ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 120, 20))
		gradient.Rotation = 90
		gradient.Parent = labels[2]
	elseif kind == "Wood" then
		local gui = surface(part, 1)
		for _, l in twoLines(gui, lines, 0.52, { Enum.Font.FredokaOne }, { DARK_BROWN }) do
			stroke(l, CREAM, 1)
		end
	elseif kind == "Banner" then
		local gui = surface(part, 0)
		for _, l in
			twoLines(
				gui,
				lines,
				0.6,
				{ Enum.Font.LuckiestGuy, Enum.Font.FredokaOne },
				{ GOLD, WHITE }
			)
		do
			stroke(l, NAVY, 3)
		end
	elseif kind == "Skins" then
		local gui = surface(part, 0.5)
		for _, l in
			twoLines(
				gui,
				lines,
				0.5,
				{ Enum.Font.LuckiestGuy },
				{ Color3.fromRGB(255, 120, 40), Color3.fromRGB(60, 140, 255) }
			)
		do
			stroke(l, WHITE, 3)
		end
	elseif kind == "Label" then
		local gui = surface(part, 0)
		for _, l in twoLines(gui, lines, 1, { Enum.Font.FredokaOne }, { WHITE }) do
			stroke(l, Color3.new(0, 0, 0), 2)
		end
	elseif kind == "BoardHeader" then
		local gui = surface(part, 0)
		twoLines(gui, lines, 0.55, { Enum.Font.FredokaOne }, { NAVY, Color3.fromRGB(170, 30, 30) })
	elseif kind == "Leaderboard" then
		leaderboardScreen(surface(part, 0))
		CollectionService:AddTag(part, "LobbyLeaderboard")
	end
end

-- Working parts ----------------------------------------------------------------------------------
local function addSeats(models: { [string]: Model })
	for i, s in Data.Seats do
		local owner = models[s.Owner]
		if owner then
			local seat = Instance.new("Seat")
			seat.Name = `Seat{i}`
			seat.Size = Vector3.new(2, 0.4, 2)
			seat.Transparency = 1
			seat.Anchored = true
			seat.CanCollide = false
			seat.CastShadow = false
			local at = point(s.Position)
			seat.CFrame = CFrame.lookAt(at, at + dir(s.Forward))
			seat.Parent = owner
		end
	end
end

local function addColliders(models: { [string]: Model })
	for _, c in Data.Colliders do
		local owner = models[c.Owner]
		if owner then
			local part = Instance.new("Part")
			part.Name = "TrunkCollider"
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(c.Height, c.Radius * 2, c.Radius * 2)
			invisible(part, true)
			-- Cylinders run along X: stand it up.
			part.CFrame = CFrame.new(point(c.Position) + Vector3.new(0, c.Height / 2, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			part.Parent = owner
		end
	end
end

local function addPrompts(models: { [string]: Model })
	for _, p in Data.Prompts do
		local owner = models[p.Owner]
		local anchor = owner and owner.PrimaryPart
		if anchor then
			local attachment = Instance.new("Attachment")
			attachment.Name = `{p.Kind}PromptPoint`
			attachment.Parent = anchor
			attachment.WorldPosition = point(p.Position)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = p.Action
			prompt.ObjectText = p.ObjectText
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = attachment
			if p.Kind == "Shop" then
				prompt:SetAttribute("Message", Config.Lobby.ShopMessage)
				CollectionService:AddTag(prompt, "AvatarShopPrompt")
			elseif p.Kind == "RewardWheel" then
				CollectionService:AddTag(prompt, "RewardWheelPrompt")
			end
		end
	end
end

local function setUpWheel(models: { [string]: Model })
	local w = Data.Wheel
	local owner = models[w.Owner]
	local wheel = owner and owner:FindFirstChild(w.Part)
	if not wheel or not wheel:IsA("BasePart") then
		warn("[SetupLobby] no reward wheel found")
		return
	end
	wheel.CanCollide, wheel.CanTouch, wheel.CanQuery = false, false, false
	-- Stored in the wheel's own space so they stay right if the wheel is moved.
	wheel:SetAttribute("SpinAxis", wheel.CFrame:VectorToObjectSpace(dir(w.Axis).Unit))
	wheel:SetAttribute("SpinCenter", wheel.CFrame:PointToObjectSpace(point(w.Center)))
	wheel:SetAttribute("Segments", w.Segments)
	wheel:SetAttribute("Angle", 0)
	CollectionService:AddTag(wheel, "RewardWheel")
end

local function addSpawn(lobby: Model)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	local at = point(Data.Spawn.Position) + Vector3.new(0, 0.5, 0)
	spawn.CFrame = CFrame.lookAt(at, at + dir(Data.Spawn.Forward))
	spawn.Parent = lobby
end

local function addBoundary(lobby: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Boundary"
	folder.Parent = lobby
	local count, radius = 36, Data.BoundaryRadius
	local width = 2 * radius * math.sin(math.pi / count) + 2
	for i = 1, count do
		local a = 2 * math.pi * i / count
		local wall = Instance.new("Part")
		wall.Name = `Wall{i}`
		wall.Size = Vector3.new(width, 90, 2)
		invisible(wall, true)
		local at = origin + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		wall.CFrame = CFrame.lookAt(at, origin * Vector3.new(1, 0, 1) + Vector3.new(0, at.Y, 0))
		wall.Parent = folder
	end
end

return function()
	local import = findImport()
	if not import then
		warn(
			"[SetupLobby] No imported lobby found. Import assets_src/lobby/UltimateTagLobby.fbx first (Import 3D), then run this again."
		)
		return
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("Before SetupLobby")
	end)

	-- Wrap the import in a Model if the importer didn't, so it can be scaled and moved as one.
	local model: Model
	if import:IsA("Model") then
		model = import
	else
		model = Instance.new("Model")
		model.Name = "LobbyImport"
		model.Parent = workspace
		import.Parent = model
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	place(model)

	local old = workspace:FindFirstChild("Lobby")
	if old and old ~= model then
		old:Destroy()
	end
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = workspace
	local models = organize(model, lobby)
	lobby.WorldPivot = CFrame.new(origin)

	for _, panel in Data.Panels do
		addPanel(panel, models)
	end
	addSeats(models)
	addColliders(models)
	addPrompts(models)
	setUpWheel(models)
	addSpawn(lobby)
	addBoundary(lobby)

	-- Whatever is left of the import (markers, empty groups) goes.
	local leftover = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not string.match(part.Name, "^Marker_") then
			leftover += 1
		end
	end
	if leftover > 0 then
		warn(`[SetupLobby] {leftover} imported pieces weren't in the lobby data; they were removed`)
	end
	model:Destroy()

	pcall(function()
		ChangeHistoryService:SetWaypoint("SetupLobby")
	end)
	print(
		`[SetupLobby] Lobby ready: {#Data.Objects} objects at {origin}. Save the place (Ctrl+S) to keep it.`
	)
end
