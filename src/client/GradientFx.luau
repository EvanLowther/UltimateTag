--!strict
-- Animates moving gradients on this screen. Every UIGradient tagged
--   HoloGradient:  flows through the Iridescent holo colors (shared/CosmeticLook),
--   ShineGradient: has its shine band swept across now and then (Legendary titles).
-- The tags are added where the gradients are made (shared/TitleTag, also on the server for
-- everyone's titles, and Menu/Ui here), so server-made titles animate on every client.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CosmeticLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticLook"))

local GradientFx = {}

local HOLO_SPEED = 0.3 -- times round the holo colors per second
local SHINE_TIME = 1.6 -- seconds a shine takes to cross
local SHINE_PAUSE = 1.2 -- seconds between shines

local function track(tag: string, set: { [UIGradient]: boolean })
	local function add(instance: Instance)
		if instance:IsA("UIGradient") then
			set[instance] = true
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		set[instance :: UIGradient] = nil
	end)
end

function GradientFx.start()
	local holo: { [UIGradient]: boolean } = {}
	local shine: { [UIGradient]: boolean } = {}
	track("HoloGradient", holo)
	track("ShineGradient", shine)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if next(holo) then
			local sequence = CosmeticLook.holoSequence((now * HOLO_SPEED) % 1)
			for gradient in holo do
				gradient.Color = sequence
			end
		end
		if next(shine) then
			local t = (now % (SHINE_TIME + SHINE_PAUSE)) / SHINE_TIME
			local offset = Vector2.new(if t <= 1 then -1 + 2 * t else 1, 0)
			for gradient in shine do
				gradient.Offset = offset
			end
		end
	end)
end

return GradientFx
