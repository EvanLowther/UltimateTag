--!strict
-- Client entry point. Requires each client module and starts it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Hud = require(script.Hud)

Hud.start()

print(`[{Config.GameName}] client started (v{Config.Version})`)
