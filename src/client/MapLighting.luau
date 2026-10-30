--!strict
-- Per-map lighting, on this client only. When the loaded map (Workspace.ActiveMap) or the lobby
-- (Workspace.Lobby, round Config.Lobby.Position) has a Lighting attribute naming a preset in
-- Config.MapLighting.Presets (like "Night") and your camera is within Config.MapLighting.Radius
-- of it, the lighting blends to that preset (on top of the normal lighting, so nothing another
-- preset changed is left behind); anywhere else it blends back to the normal lighting from
-- default.project.json. Spectators following someone on the map see the map's lighting too,
-- since it follows the camera. A showcase (the win screen, the Locker) sets its own preset with
-- `override`. When the camera jumps far (a teleport, a respawn, a showcase opening or closing) the
-- lighting switches at once instead of blending, so nothing is seen half lit.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapLighting = {}

local CHECK_EVERY = 0.25 -- seconds between checks
local JUMP = 150 -- studs the camera moves between checks that count as a jump (switch at once)

type Values = { [string]: { [string]: any } }

-- The game's own lighting instance named `name` (default.project.json), never another effect
-- added for a moment (the victories add their own).
local function named(name: string, className: string): Instance?
	local item = Lighting:FindFirstChild(name)
	return if item and item:IsA(className) then item else nil
end

-- The instances a preset can change, by the preset's section names.
local function targets(): { [string]: Instance? }
	return {
		Lighting = Lighting,
		Atmosphere = named("Atmosphere", "Atmosphere"),
		Bloom = named("Bloom", "BloomEffect"),
		ColorCorrection = named("ColorCorrection", "ColorCorrectionEffect"),
	}
end

-- The current values of every property any preset touches (the normal lighting).
local function snapshot(): Values
	local saved: Values = {}
	local instances = targets()
	for _, preset in Config.MapLighting.Presets do
		for section, props in preset :: Values do
			local instance = instances[section]
			if instance then
				saved[section] = saved[section] or {}
				for name in props do
					saved[section][name] = (instance :: any)[name]
				end
			end
		end
	end
	return saved
end

local tweens: { Tween } = {}

-- Moves the lighting to `values` over `seconds` (0: at once).
local function blend(values: Values, seconds: number)
	for _, tween in tweens do
		tween:Cancel()
	end
	table.clear(tweens)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for section, props in values do
		local instance = targets()[section]
		if instance then
			if seconds <= 0 then
				for name, value in props do
					(instance :: any)[name] = value
				end
			else
				local tween = TweenService:Create(instance, info, props)
				tween:Play()
				table.insert(tweens, tween)
			end
		end
	end
end

-- A place's preset and how far the camera is from it (nil if it has no preset).
local function presetAt(place: Instance?, center: Vector3?): (string?, number)
	if not place or not place:IsA("Model") then
		return nil, math.huge
	end
	local name = place:GetAttribute("Lighting")
	if type(name) ~= "string" or not Config.MapLighting.Presets[name] then
		return nil, math.huge
	end
	local focus = workspace.CurrentCamera.Focus.Position
	return name, (focus - (center or place:GetPivot().Position)).Magnitude
end

-- The preset the camera should see right now (the nearest place's within reach), or nil for the
-- normal lighting.
local function wantedPreset(): string?
	local mapPreset, mapDistance = presetAt(workspace:FindFirstChild("ActiveMap"), nil)
	-- The lobby's middle from Config (its streamed-in parts move its pivot about).
	local lobbyPreset, lobbyDistance =
		presetAt(workspace:FindFirstChild("Lobby"), Config.Lobby.Position)
	local name, distance = mapPreset, mapDistance
	if lobbyDistance < mapDistance then
		name, distance = lobbyPreset, lobbyDistance
	end
	return if distance <= Config.MapLighting.Radius then name else nil
end

-- A preset laid over the normal lighting, so whatever another preset changed goes back too.
local function over(normal: Values, preset: Values): Values
	local values: Values = {}
	for section, props in normal do
		values[section] = table.clone(props)
	end
	for section, props in preset do
		values[section] = values[section] or {}
		for name, value in props do
			values[section][name] = value
		end
	end
	return values
end

local normal: Values = {}
local current: string? = nil
local overridden: string? = nil
local lastFocus: Vector3? = nil
local started = false

-- Picks the preset for where the camera is now (or the override) and moves to it, at once if
-- `snap` or the camera jumped.
local function update(snap: boolean)
	local focus = workspace.CurrentCamera.Focus.Position
	local jumped = lastFocus == nil or (focus - lastFocus :: Vector3).Magnitude > JUMP
	lastFocus = focus
	local wanted = overridden or wantedPreset()
	if wanted ~= current then
		current = wanted
		local values = if wanted
			then over(normal, Config.MapLighting.Presets[wanted] :: Values)
			else normal
		blend(values, if snap or jumped then 0 else Config.MapLighting.FadeTime)
	end
end

-- A showcase's own lighting (a preset name) while it's open, switched at once; nil hands the
-- lighting back to wherever the camera is.
function MapLighting.override(name: string?)
	if name and not Config.MapLighting.Presets[name] then
		return
	end
	overridden = name
	if started then
		update(true)
	end
end

function MapLighting.start()
	normal = snapshot()
	started = true
	task.spawn(function()
		while true do
			update(false)
			task.wait(CHECK_EVERY)
		end
	end)
end

return MapLighting
