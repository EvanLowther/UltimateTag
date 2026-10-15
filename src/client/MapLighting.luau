--!strict
-- Per-map lighting, on this client only. When the loaded map (Workspace.ActiveMap) or the lobby
-- (Workspace.Lobby, round Config.Lobby.Position) has a Lighting attribute naming a preset in
-- Config.MapLighting.Presets (like "Night") and your camera is within Config.MapLighting.Radius
-- of it, the lighting blends to that preset (on top of the normal lighting, so nothing another
-- preset changed is left behind); anywhere else it blends back to the normal lighting from
-- default.project.json. Spectators following someone on the map see the map's lighting too,
-- since it follows the camera.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapLighting = {}

local CHECK_EVERY = 0.25 -- seconds between checks

type Values = { [string]: { [string]: any } }

-- The instances a preset can change, by the preset's section names.
local function targets(): { [string]: Instance? }
	return {
		Lighting = Lighting,
		Atmosphere = Lighting:FindFirstChildOfClass("Atmosphere"),
		Bloom = Lighting:FindFirstChildOfClass("BloomEffect"),
		ColorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect"),
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

local function blend(values: Values, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for section, props in values do
		local instance = targets()[section]
		if instance then
			TweenService:Create(instance, info, props):Play()
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

function MapLighting.start()
	local normal = snapshot()
	local current: string? = nil
	task.spawn(function()
		while true do
			local wanted = wantedPreset()
			if wanted ~= current then
				current = wanted
				local values = if wanted
					then over(normal, Config.MapLighting.Presets[wanted] :: Values)
					else normal
				blend(values, Config.MapLighting.FadeTime)
			end
			task.wait(CHECK_EVERY)
		end
	end)
end

return MapLighting
