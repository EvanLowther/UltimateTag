--!strict
-- Tells the server you are there (the AFK check, server/Afk): when you press a key or button,
-- touch the screen, or move the mouse or a thumbstick, it sends the Activity remote, at most
-- once every Config.Afk.PingInterval seconds. Costs nothing when idle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Activity = {}

local MOVING = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.Gamepad1] = true,
}

function Activity.start()
	local remote = Remotes.get("Activity")
	local pending = false -- input since the last ping
	local lastPing = -math.huge

	local function seen()
		local now = os.clock()
		if now - lastPing >= Config.Afk.PingInterval then
			lastPing = now
			pending = false
			remote:FireServer()
		else
			pending = true -- sent by the loop below once the interval is up
		end
	end

	UserInputService.InputBegan:Connect(function()
		seen()
	end)
	UserInputService.InputChanged:Connect(function(input)
		if MOVING[input.UserInputType] then
			-- (mouse movement while the mouse is free is also activity)
			seen()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Afk.PingInterval)
			if pending then
				seen()
			end
		end
	end)
end

return Activity
