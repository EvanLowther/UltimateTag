--!strict
-- Tells the server when a move starts (for stats, quests and achievements): watches
-- MoveState.busy and reports each new WallRun, Slide, Vault and Climb through the MoveDone
-- remote. Hops up the same wall (Climb -> Cling -> Climb) count once. The server only counts
-- moves made during a live round.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local MoveState = require(script.Parent.MoveState)

local MoveReport = {}

local REPORTED = { WallRun = true, Slide = true, Vault = true, Climb = true }
local CLIMBING = { Climb = true, Cling = true, Hang = true }

function MoveReport.start()
	local remote = Remotes.get("MoveDone")
	local last: string? = nil
	RunService.Heartbeat:Connect(function()
		local now = MoveState.busy
		if now ~= last then
			local stillClimbing = now and last and CLIMBING[now] and CLIMBING[last]
			if now and REPORTED[now] and not stillClimbing then
				remote:FireServer(now)
			end
			last = now
		end
	end)
end

return MoveReport
