--!strict
-- The one place that changes Humanoid.HipHeight and CameraOffset, so moves (slide, vault) can
-- lower the body without fighting each other. Heights are a fraction of normal standing height.
local RunService = game:GetService("RunService")

local Crouch = {}

type State = {
	factor: number,
	factorTarget: number,
	factorRate: number,
	dip: number,
	dipTarget: number,
	dipRate: number,
}

local STANDING_ATTRIBUTE = "StandingHipHeight"

local states: { [Humanoid]: State } = {}
local connection: RBXScriptConnection? = nil

local function approach(value: number, target: number, rate: number, dt: number): number
	if value < target then
		return math.min(value + rate * dt, target)
	end
	return math.max(value - rate * dt, target)
end

-- The character's normal hip height, remembered the first time it's asked for.
function Crouch.standingHip(humanoid: Humanoid): number
	local saved = humanoid:GetAttribute(STANDING_ATTRIBUTE)
	if typeof(saved) == "number" then
		return saved
	end
	humanoid:SetAttribute(STANDING_ATTRIBUTE, humanoid.HipHeight)
	return humanoid.HipHeight
end

local function step(dt: number)
	for humanoid, state in states do
		if not humanoid.Parent then
			states[humanoid] = nil
			continue
		end
		state.factor = approach(state.factor, state.factorTarget, state.factorRate, dt)
		state.dip = approach(state.dip, state.dipTarget, state.dipRate, dt)
		humanoid.HipHeight = Crouch.standingHip(humanoid) * state.factor
		humanoid.CameraOffset = Vector3.new(0, -state.dip, 0)
		-- Back to normal: stop updating this character.
		if
			state.factor == 1
			and state.factorTarget == 1
			and state.dip == 0
			and state.dipTarget == 0
		then
			states[humanoid] = nil
		end
	end
	if next(states) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- Eases the hips to `factor` x standing height (1 = standing) and the camera down by
-- `cameraDip` studs, over `seconds`.
function Crouch.set(humanoid: Humanoid, factor: number, seconds: number, cameraDip: number)
	local standing = Crouch.standingHip(humanoid)
	local state = states[humanoid]
	if not state then
		state = {
			factor = humanoid.HipHeight / standing,
			factorTarget = 1,
			factorRate = 0,
			dip = -humanoid.CameraOffset.Y,
			dipTarget = 0,
			dipRate = 0,
		}
		states[humanoid] = state
	end
	local s = state :: State
	local time = math.max(seconds, 1e-3)
	s.factorTarget = factor
	s.factorRate = math.abs(factor - s.factor) / time
	s.dipTarget = cameraDip
	s.dipRate = math.abs(cameraDip - s.dip) / time
	if not connection then
		connection = RunService.PreSimulation:Connect(step)
	end
end

return Crouch
