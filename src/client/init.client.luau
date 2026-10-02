--!strict
-- Client entry point. Requires each client module and starts it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AirStrafe = require(script.AirStrafe)
local Hud = require(script.Hud)
local Mantle = require(script.Mantle)
local Slide = require(script.Slide)
local Sprint = require(script.Sprint)
local Vault = require(script.Vault)
local WallBounce = require(script.WallBounce)

Hud.start()
Sprint.start()
Slide.start()
Vault.start()
Mantle.start()
WallBounce.start()
AirStrafe.start()

print(`[{Config.GameName}] client started (v{Config.Version})`)
