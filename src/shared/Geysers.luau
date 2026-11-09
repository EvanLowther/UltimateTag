--!strict
-- Timed geysers (the Desert Mine): a launch pad (LaunchVelocity) with GeyserPeriod, GeyserRumble,
-- GeyserBlow and GeyserPhase attributes (seconds). Each cycle ends with the rumble and then the
-- blast, worked out from the server clock so every screen agrees. client/Geysers shows it,
-- client/MapGadgets only throws you during the blast, and bots leave geysers alone.
local Geysers = {}

export type State = "Idle" | "Rumble" | "Blow"

function Geysers.isGeyser(part: Instance): boolean
	return type(part:GetAttribute("GeyserPeriod")) == "number"
end

function Geysers.state(part: Instance, serverTime: number): State
	local period = part:GetAttribute("GeyserPeriod") :: number
	local blow = (part:GetAttribute("GeyserBlow") or 3) :: number
	local rumble = (part:GetAttribute("GeyserRumble") or 2) :: number
	local at = (serverTime + ((part:GetAttribute("GeyserPhase") or 0) :: number)) % period
	if at >= period - blow then
		return "Blow"
	elseif at >= period - blow - rumble then
		return "Rumble"
	end
	return "Idle"
end

return Geysers
