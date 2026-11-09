--!strict
-- Shows the timed geysers on the loaded map (shared/Geysers): each vent's `Rumble` particles run
-- during its warning and its `Steam` particles during the blast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GeyserState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Geysers"))

local Geysers = {}

local vents: { BasePart } = {}
local watched: Instance? = nil

local function consider(item: Instance)
	if item:IsA("BasePart") and GeyserState.isGeyser(item) then
		table.insert(vents, item)
	end
end

local function watch(map: Instance?)
	table.clear(vents)
	watched = map
	if map then
		for _, item in map:GetDescendants() do
			consider(item)
		end
	end
end

local function setEmitter(part: BasePart, name: string, on: boolean)
	local emitter = part:FindFirstChild(name)
	if emitter and emitter:IsA("ParticleEmitter") and emitter.Enabled ~= on then
		emitter.Enabled = on
	end
end

function Geysers.start()
	RunService.Heartbeat:Connect(function()
		local map = workspace:FindFirstChild("ActiveMap")
		if map ~= watched then
			watch(map)
		end
		if #vents == 0 then
			return
		end
		local t = workspace:GetServerTimeNow()
		for _, vent in vents do
			local state = GeyserState.state(vent, t)
			setEmitter(vent, "Steam", state == "Blow")
			setEmitter(vent, "Rumble", state == "Rumble")
		end
	end)
end

return Geysers
