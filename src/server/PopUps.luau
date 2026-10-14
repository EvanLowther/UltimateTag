--!strict
-- Pop-ups (the Playroom's jack-in-the-box; client/PopUps animates them). A pop-up's pad is a
-- launch pad (LaunchVelocity) with a PopUp name. When someone launches off it their client says
-- so (the PopUp remote); if the toy is ready (not still out from the last time, PopCooldown) and
-- they're by the pad, it springs for everyone: the pad's PopAt becomes the server time, and every
-- client plays it from there. Until it has wound back down the pad launches nobody.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PopUps = {}

local function spring(player: Player, pad: any)
	if typeof(pad) ~= "Instance" or not pad:IsA("BasePart") then
		return
	end
	local map = workspace:FindFirstChild("ActiveMap")
	if not map or not pad:IsDescendantOf(map) then
		return
	end
	if
		type(pad:GetAttribute("PopUp")) ~= "string"
		or typeof(pad:GetAttribute("LaunchVelocity")) ~= "Vector3"
	then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - pad.Position).Magnitude > Config.PopUps.TriggerRange then
		return
	end
	local now = workspace:GetServerTimeNow()
	local popAt, cooldown = pad:GetAttribute("PopAt"), pad:GetAttribute("PopCooldown")
	if type(popAt) == "number" and type(cooldown) == "number" and now < popAt + cooldown then
		return -- still out
	end
	pad:SetAttribute("PopAt", now)
end

function PopUps.start()
	Remotes.get("PopUp").OnServerEvent:Connect(spring)
end

return PopUps
