--!strict
-- Victories: the winner's celebration on the win screen (client/WinScreen), also previewed in
-- the Locker (client/LockerStage). Each Victory item's look names one (`look.Victory`) and how
-- long it plays (`look.Length`; the server makes the win screen long enough for it). The plan
-- with every beat is docs/polish/victories.md.
--   Epic: Flex, Backflip, Confetti Storm, Breakdance, Katana, Trophy Lift (Victories/Epic).
--   Legendary: Podium Rise, Thunderstorm, Throne, Meteor Touchdown (Victories/Legendary).
--   Iridescent: Supernova, Rift (Victories/Iridescent).
-- Everything runs on this screen only, from the same data, so everyone sees the same thing.
-- One plays at a time: `stop` clears it (the win screen closing, the Locker switching items).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Epic = require(script.Epic)
local Iridescent = require(script.Iridescent)
local Kit = require(script.Kit)
local Legendary = require(script.Legendary)

local Victories = {}

local PLAYS: { [string]: (Kit.Context) -> () } = {
	Flex = Epic.Flex,
	Backflip = Epic.Backflip,
	ConfettiStorm = Epic.ConfettiStorm,
	Breakdance = Epic.Breakdance,
	Katana = Epic.Katana,
	TrophyLift = Epic.TrophyLift,
	PodiumRise = Legendary.PodiumRise,
	Thunderstorm = Legendary.Thunderstorm,
	Throne = Legendary.Throne,
	MeteorTouchdown = Legendary.MeteorTouchdown,
	Supernova = Iridescent.Supernova,
	Rift = Iridescent.Rift,
}

local DEFAULT_COLORS = {
	Color3.fromRGB(255, 214, 10),
	Color3.fromRGB(255, 62, 138),
	Color3.fromRGB(34, 211, 238),
}

export type Options = {
	hold: number, -- seconds before the victory lets go
	floor: number?, -- the stage floor's y (default: what they stand on)
	block: BasePart?, -- the 1st place block under them
	blocks: { BasePart }?, -- every podium block, 1st first
	others: { Model }?, -- the other podium copies (may still be arriving)
	stage: Instance?, -- the whole stage
}

-- Plays `item` on `character` (a posed copy with an anchored root, facing the camera).
function Victories.play(character: Model, item: Catalog.Item?, options: Options)
	Kit.stop()
	if not item then
		return
	end
	local play = PLAYS[item.look.Victory]
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not play or not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	local ground = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
	local context: Kit.Context = {
		character = character,
		root = root,
		humanoid = humanoid,
		item = item,
		colors = (item.look.Colors or DEFAULT_COLORS) :: { Color3 },
		home = character:GetPivot(),
		ground = ground,
		floor = options.floor or ground,
		block = options.block,
		blocks = options.blocks or {},
		others = options.others or {},
		stage = options.stage,
		hold = options.hold,
		started = os.clock(),
	}
	Kit.begin(context)
	play(context)
end

function Victories.stop()
	Kit.stop()
end

-- The win screen's or Locker's camera with the playing victory's shakes and tilt laid on.
function Victories.camera(cframe: CFrame): CFrame
	return Kit.camera(cframe)
end

return Victories
