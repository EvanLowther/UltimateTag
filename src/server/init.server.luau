--!strict
-- Server entry point. Requires each service module and starts it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Avatar = require(script.Avatar)
local GameLoop = require(script.GameLoop)
local CollisionGroups = require(script.CollisionGroups)
local Leaderstats = require(script.Leaderstats)
local Roles = require(script.Roles)
local TagService = require(script.TagService)

Remotes.setup()
Avatar.start()
CollisionGroups.start()
Leaderstats.start()
Roles.start()
TagService.start()
GameLoop.start()

print(`[{Config.GameName}] server started (v{Config.Version})`)
