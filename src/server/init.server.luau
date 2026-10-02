--!strict
-- Server entry point. Requires each service module and starts it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

print(`[{Config.GameName}] server started (v{Config.Version})`)
