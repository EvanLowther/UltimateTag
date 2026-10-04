--!strict
-- Per-map lighting, on this client only. When the loaded map (Workspace.ActiveMap) has a
-- Lighting attribute naming a preset in Config.MapLighting.Presets (like "Night") and your
-- camera is within Config.MapLighting.Radius of it, the lighting blends to that preset; anywhere
-- else (the lobby) it blends back to the normal lighting from default.project.json. Spectators
-- following someone on the map see the map's lighting too, since it follows the camera.
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

-- The preset the camera should see right now, or nil for the normal lighting.
local function wantedPreset(): string?
	local map = workspace:FindFirstChild("ActiveMap")
	if not map or not map:IsA("Model") then
		return nil
	end
	local name = map:GetAttribute("Lighting")
	if type(name) ~= "string" or not Config.MapLighting.Presets[name] then
		return nil
	end
	local camera = workspace.CurrentCamera
	local distance = (camera.Focus.Position - map:GetPivot().Position).Magnitude
	return if distance <= Config.MapLighting.Radius then name else nil
end

function MapLighting.start()
	local normal = snapshot()
	local current: string? = nil
	task.spawn(function()
		while true do
			local wanted = wantedPreset()
			if wanted ~= current then
				current = wanted
				local values = if wanted then Config.MapLighting.Presets[wanted] else normal
				blend(values :: Values, Config.MapLighting.FadeTime)
			end
			task.wait(CHECK_EVERY)
		end
	end)
end

return MapLighting
