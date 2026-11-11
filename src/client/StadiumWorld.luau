--!strict
-- Tag Stadium on your screen (tools/stadium_layout.py; server/StadiumWorld does the server's
-- side). Everything is worked out from the server's clock, so every player sees the same:
--   - the lifting pitch chunks (shared/PitchChunks): moved here every frame they move, their
--     edges (`ChunkSeam`) flash before they go, and a sinking one pushes you out from under it;
--   - the LED screens: Textures with `LedStart` scroll Config.Stadium.LedFlow studs a second
--     towards their right (+U), the way the strip's arrows point, continuous round each loop;
--   - the crowd: 3D fans (`FanId`, `FanF`) jump on their own beat with a wave running round,
--     fans' flags (`Waver`) swing, roof flags (`RoofFlag`) stir, the crowd pictures (`CrowdBob`)
--     bob, and the choreography's cards (`ChoreoA`/`ChoreoB`) flip in a sweep across the curve;
--   - smoke flares (`FlareGroup`): each group burns for FlareBurn seconds of every FlarePeriod;
--   - the scoreboards' clocks count up from kick-off (the map's StadiumEpoch).
-- Pictures: any Texture, Decal or ImageLabel with an `Image` attribute gets that uploaded image
-- (shared/MapImages); until it's uploaded it shows nothing and the parts' own colours show.
-- Nothing moves while your camera is far from the map (in the lobby, say).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapImages = require(Shared:WaitForChild("MapImages"))
local PitchChunks = require(Shared:WaitForChild("PitchChunks"))
local MoveState = require(script.Parent.MoveState)
local Sounds = require(script.Parent.Sounds)

local StadiumWorld = {}

type Moving = { parts: { BasePart }, base: { CFrame }, frames: { CFrame } }
type Led = { texture: Texture, start: number }
type Panel = { frames: { Frame }, a: { Color3 }, b: { Color3 }, u: number, showing: number }
type Flare = { emitter: ParticleEmitter, part: BasePart, group: number, on: boolean }

local map: Instance? = nil
local dirtyAt: number? = nil
local added: RBXScriptConnection? = nil
local active = false

local pieces: { PitchChunks.Piece } = {}
local slotCenter: { [number]: Vector3 } = {}
local seams: { [number]: { BasePart } } = {}
local lastF: { [number]: number } = {}
local leds: { Led } = {}
local fans: Moving = { parts = {}, base = {}, frames = {} }
local fanId: { number } = {}
local fanF: { number } = {}
local wavers: Moving = { parts = {}, base = {}, frames = {} }
local waverInfo: { { pivot: Vector3, axis: Vector3, id: number } } = {}
local roofFlags: Moving = { parts = {}, base = {}, frames = {} }
local roofPivot: { Vector3 } = {}
local pictures: { { texture: Texture, phase: number } } = {}
local panels: { Panel } = {}
local flares: { Flare } = {}
local clocks: { TextLabel } = {}
local lastCrowd = 0
local lastClock = -1

-- A steady pseudo-random number in [0, 1) for `n`, so every screen picks the same.
local function hash(n: number, salt: number): number
	local x = math.sin(n * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function colors(text: string): { Color3 }
	local out = {}
	for chunk in string.gmatch(text, "[^|]+") do
		local r, g, b = string.match(chunk, "(%d+),(%d+),(%d+)")
		table.insert(out, Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0))
	end
	return out
end

local function applyImage(item: Instance)
	local name = item:GetAttribute("Image")
	if type(name) ~= "string" then
		return
	end
	local id = MapImages[name]
	if not id then
		return
	end
	if item:IsA("Decal") then -- (a Texture is a kind of Decal)
		item.Texture = id
	elseif item:IsA("ImageLabel") then
		item.Image = id
	end
end

local function add(group: Moving, part: BasePart)
	table.insert(group.parts, part)
	table.insert(group.base, part.CFrame)
	table.insert(group.frames, part.CFrame)
end

local function clearAll()
	table.clear(pieces)
	table.clear(slotCenter)
	table.clear(seams)
	table.clear(lastF)
	table.clear(leds)
	for _, group in { fans, wavers, roofFlags } do
		table.clear(group.parts)
		table.clear(group.base)
		table.clear(group.frames)
	end
	table.clear(fanId)
	table.clear(fanF)
	table.clear(waverInfo)
	table.clear(roofPivot)
	table.clear(pictures)
	table.clear(panels)
	table.clear(flares)
	table.clear(clocks)
end

local function scan(target: Instance)
	clearAll()
	local sums: { [number]: Vector3 } = {}
	local counts: { [number]: number } = {}
	for _, item in target:GetDescendants() do
		applyImage(item)
		if item:IsA("BasePart") then
			local slot = item:GetAttribute("ChunkSlot")
			if type(slot) == "number" then
				local piece = PitchChunks.piece(item)
				if piece then
					table.insert(pieces, piece)
					sums[slot] = (sums[slot] or Vector3.zero) + item.Position
					counts[slot] = (counts[slot] or 0) + 1
				end
			end
			local seam = item:GetAttribute("ChunkSeam")
			if type(seam) == "number" then
				seams[seam] = seams[seam] or {}
				table.insert(seams[seam], item)
			end
			local id = item:GetAttribute("FanId")
			if type(id) == "number" then
				add(fans, item)
				table.insert(fanId, id)
				table.insert(fanF, (item:GetAttribute("FanF") or 0) :: number)
			end
			local waver = item:GetAttribute("Waver")
			local pivot = item:GetAttribute("WaverPivot")
			local axis = item:GetAttribute("WaverAxis")
			if
				type(waver) == "number"
				and typeof(pivot) == "Vector3"
				and typeof(axis) == "Vector3"
			then
				add(wavers, item)
				table.insert(waverInfo, { pivot = pivot, axis = axis.Unit, id = waver })
			end
			local roof = item:GetAttribute("RoofFlag")
			if typeof(roof) == "Vector3" then
				add(roofFlags, item)
				table.insert(roofPivot, roof)
			end
			local bob = item:GetAttribute("CrowdBob")
			if type(bob) == "number" then
				local texture = item:FindFirstChildOfClass("Texture")
				if texture then
					table.insert(pictures, { texture = texture, phase = bob * math.pi * 2 })
				end
			end
			local choreoA, choreoB = item:GetAttribute("ChoreoA"), item:GetAttribute("ChoreoB")
			if type(choreoA) == "string" and type(choreoB) == "string" then
				local gui = item:FindFirstChildOfClass("SurfaceGui")
				local frames = {}
				if gui then
					for c = 1, 4 do
						local frame = gui:FindFirstChild("Card" .. c)
						if frame and frame:IsA("Frame") then
							table.insert(frames, frame)
						end
					end
				end
				table.insert(panels, {
					frames = frames,
					a = colors(choreoA),
					b = colors(choreoB),
					u = (item:GetAttribute("ChoreoU") or 0) :: number,
					showing = -1,
				})
			end
			local group = item:GetAttribute("FlareGroup")
			if type(group) == "number" then
				local emitter = item:FindFirstChildOfClass("ParticleEmitter")
				if emitter then
					table.insert(
						flares,
						{ emitter = emitter, part = item, group = group, on = false }
					)
				end
			end
		elseif item:IsA("Texture") and type(item:GetAttribute("LedStart")) == "number" then
			table.insert(leds, { texture = item, start = item:GetAttribute("LedStart") :: number })
		elseif item:IsA("TextLabel") and item.Name == "Clock" then
			table.insert(clocks, item)
		end
	end
	for slot, sum in sums do
		slotCenter[slot] = sum / counts[slot]
	end
end

local function moveChunks(t: number, seed: number)
	local s = Config.Stadium
	local up, changing = PitchChunks.at(t, seed)
	local moved: { BasePart } = {}
	local frames: { CFrame } = {}
	local sinking: { [number]: boolean } = {}
	for slot, f in up do
		local before = lastF[slot]
		if before ~= f then
			if before and (before == 0 or before == 1) and f > 0 and f < 1 then
				local center = slotCenter[slot]
				if center then
					Sounds.at("chunk_move", center)
				end
			end
			if before and f < before then
				sinking[slot] = true
			end
		end
	end
	for _, piece in pieces do
		if lastF[piece.slot] ~= up[piece.slot] then
			table.insert(moved, piece.part)
			table.insert(frames, PitchChunks.frame(piece, up[piece.slot]))
		end
	end
	if #moved > 0 then
		workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- Under a sinking chunk: out you go, to just past its edge.
	local parts = MoveState.parts()
	if parts and not parts.root.Anchored and next(sinking) then
		for _, piece in pieces do
			if sinking[piece.slot] and piece.part.CanCollide then
				local out = PitchChunks.outFrom(piece.part, parts.root.Position, s.PushOut)
				if out then
					parts.root.CFrame = parts.root.CFrame.Rotation + out
				end
			end
		end
	end
	local blink = math.floor(t * 4) % 2 == 0
	for slot, list in seams do
		local color = if changing[slot] and blink then s.WarnOn else s.WarnOff
		for _, seam in list do
			if seam.Color ~= color then
				seam.Color = color
			end
		end
	end
	for slot, f in up do
		lastF[slot] = f
	end
end

local function moveCrowd(t: number)
	local s = Config.Stadium
	-- Fans jump; the wave lifts them as it passes.
	local wave = (t * s.WaveSpeed) % 1
	for i = 1, #fans.parts do
		local id = fanId[i]
		local jump = s.FanJump[1] + hash(id, 1) * (s.FanJump[2] - s.FanJump[1])
		local beat = s.FanBeat[1] + hash(id, 2) * (s.FanBeat[2] - s.FanBeat[1])
		local y = jump * math.max(0, math.sin(t * beat + hash(id, 3) * math.pi * 2))
		local d = math.abs(fanF[i] - wave)
		if d > 0.5 then
			d = 1 - d
		end
		if d < s.WaveWidth then
			y += (1 - d / s.WaveWidth) * s.WaveHeight
		end
		fans.frames[i] = fans.base[i] + Vector3.new(0, y, 0)
	end
	if #fans.parts > 0 then
		workspace:BulkMoveTo(fans.parts, fans.frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for i = 1, #wavers.parts do
		local info = waverInfo[i]
		local beat = s.WaverBeat[1] + hash(info.id, 4) * (s.WaverBeat[2] - s.WaverBeat[1])
		local angle = s.WaverSwing * math.sin(t * beat + hash(info.id, 5) * math.pi * 2)
		local turn = CFrame.new(info.pivot)
			* CFrame.fromAxisAngle(info.axis, angle)
			* CFrame.new(-info.pivot)
		wavers.frames[i] = turn * wavers.base[i]
	end
	if #wavers.parts > 0 then
		workspace:BulkMoveTo(wavers.parts, wavers.frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for i = 1, #roofFlags.parts do
		local pivot = roofPivot[i]
		local angle = s.RoofFlagSway * math.sin(t * 1.3 + i * 1.7)
		roofFlags.frames[i] = CFrame.new(pivot)
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(-pivot)
			* roofFlags.base[i]
	end
	if #roofFlags.parts > 0 then
		workspace:BulkMoveTo(roofFlags.parts, roofFlags.frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for _, picture in pictures do
		picture.texture.OffsetStudsV = s.CrowdBob * math.max(0, math.sin(t * 7 + picture.phase))
	end
	-- The choreography: a flip sweeps across the curve every ChoreoFlip seconds.
	local cycle = t % (2 * s.ChoreoFlip)
	for _, panel in panels do
		local lead = s.ChoreoSweep * panel.u
		local showB = if cycle >= s.ChoreoFlip + lead or cycle < lead then 1 else 0
		if showB ~= panel.showing then
			panel.showing = showB
			local list = if showB == 1 then panel.b else panel.a
			for c, frame in panel.frames do
				frame.BackgroundColor3 = list[c] or frame.BackgroundColor3
			end
		end
	end
	-- LED screens scroll the way their arrows point (+U), continuous round each loop.
	for _, led in leds do
		local tile = led.texture.StudsPerTileU
		led.texture.OffsetStudsU = (s.LedFlow * t - led.start) % tile
	end
end

local function lightFlares(t: number)
	local s = Config.Stadium
	for _, flare in flares do
		local offset = (flare.group - 1) * s.FlarePeriod / s.FlareGroups
		local on = (t + offset) % s.FlarePeriod < s.FlareBurn
		if on ~= flare.on then
			flare.on = on
			flare.emitter.Enabled = on
			if on then
				Sounds.at("flare_hiss", flare.part)
			end
		end
	end
end

local function step()
	local current = workspace:FindFirstChild("ActiveMap")
	if current ~= map then
		if added then
			added:Disconnect()
			added = nil
		end
		map = current
		active = false
		dirtyAt = nil
		clearAll()
		if map and map:GetAttribute("Stadium") == true then
			dirtyAt = os.clock()
			added = map.DescendantAdded:Connect(function()
				dirtyAt = os.clock()
			end)
		end
	end
	if not map then
		return
	end
	if dirtyAt and os.clock() - dirtyAt > 0.4 then
		dirtyAt = nil
		scan(map)
		active = true
	end
	if not active then
		return
	end
	local s = Config.Stadium
	if workspace.CurrentCamera.CFrame.Position.Magnitude > s.ActiveRange then
		return
	end
	local t = workspace:GetServerTimeNow()
	local seed = map:GetAttribute("ChunkSeed")
	if type(seed) == "number" then
		moveChunks(t, seed)
	end
	if os.clock() - lastCrowd >= 1 / s.CrowdRate then
		lastCrowd = os.clock()
		moveCrowd(t)
		lightFlares(t)
	end
	local epoch = map:GetAttribute("StadiumEpoch")
	if type(epoch) == "number" then
		local seconds = math.max(0, math.floor(t - epoch))
		if seconds ~= lastClock then
			lastClock = seconds
			local text = string.format("%02d:%02d", math.floor(seconds / 60) % 100, seconds % 60)
			for _, label in clocks do
				label.Text = text
			end
		end
	end
end

function StadiumWorld.start()
	RunService.PreSimulation:Connect(step)
end

return StadiumWorld
