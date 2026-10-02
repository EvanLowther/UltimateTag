--!strict
-- Server entry point. Requires each service module and starts it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CollisionGroups = require(script.CollisionGroups)
local Leaderstats = require(script.Leaderstats)
local Roles = require(script.Roles)
local Sandbox = require(script.Sandbox)
local TagService = require(script.TagService)

CollisionGroups.start()
Leaderstats.start()
Roles.start()
TagService.start()
Sandbox.start()

print(`[{Config.GameName}] server started (v{Config.Version})`)
