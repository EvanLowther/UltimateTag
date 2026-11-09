--!strict
-- The ZiplineRide remote: a player's screen says they got on or off a zipline (client/Ziplines),
-- and this marks their character, so every screen shows them hanging from the line.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Ziplines = {}

function Ziplines.start()
	Remotes.get("ZiplineRide").OnServerEvent:Connect(function(player: Player, riding: any)
		local character = player.Character
		if character and type(riding) == "boolean" then
			character:SetAttribute("Riding", if riding then true else nil)
		end
	end)
end

return Ziplines
