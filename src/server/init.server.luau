--!strict
-- Server entry point. Requires each service module and starts it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Leaderstats = require(script.Leaderstats)
local Roles = require(script.Roles)
local RoundService = require(script.RoundService)
local TagService = require(script.TagService)

Leaderstats.start()
Roles.start()
TagService.start()
RoundService.start()

print(`[{Config.GameName}] server started (v{Config.Version})`)
