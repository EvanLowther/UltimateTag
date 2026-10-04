--!strict
-- The lobby's daily reward wheel. Its ProximityPrompt (tagged "RewardWheelPrompt") spins the
-- wheel part (tagged "RewardWheel", both made by tools/SetupLobby) for everyone to see, landing
-- on a random segment; the player is told their prize (Config.Lobby.WheelPrizes). One spin per
-- player every Config.Lobby.WheelCooldownHours, saved when data stores are available.
--
-- The wheel part carries attributes from the setup tool, in its own space so they survive it
-- being moved: SpinAxis (out of its front), SpinCenter, Segments, and Angle (how far it has
-- turned). Segment i starts at (i - 1) x 360 / Segments degrees, counterclockwise from the
-- wheel's right as you face it; the pointer is at the top (90 degrees).
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local RewardWheel = {}

local spinning: { [BasePart]: boolean } = {}
local lastSpin: { [number]: number } = {}
local spinStore: DataStore? = nil
local storeOn = true

local function store(): DataStore?
	if storeOn and not spinStore then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("WheelSpins_v1")
		end)
		if ok then
			spinStore = result
		else
			storeOn = false
		end
	end
	return spinStore
end

local function lastSpinOf(player: Player): number
	if lastSpin[player.UserId] then
		return lastSpin[player.UserId]
	end
	local s = store()
	if s then
		local ok, value = pcall(function()
			return s:GetAsync(`Player_{player.UserId}`)
		end)
		if ok then
			lastSpin[player.UserId] = tonumber(value) or 0
			return lastSpin[player.UserId]
		end
		storeOn = false
	end
	return 0
end

local function rememberSpin(player: Player, time: number)
	lastSpin[player.UserId] = time
	local s = store()
	if s then
		task.spawn(pcall, function()
			s:SetAsync(`Player_{player.UserId}`, time)
		end)
	end
end

-- Turns the wheel by `degrees` about its own axis.
local function turn(wheel: BasePart, degrees: number)
	local axis = wheel.CFrame:VectorToWorldSpace(wheel:GetAttribute("SpinAxis") :: Vector3)
	local center = wheel.CFrame:PointToWorldSpace(wheel:GetAttribute("SpinCenter") :: Vector3)
	wheel.CFrame = CFrame.new(center)
		* CFrame.fromAxisAngle(axis, math.rad(degrees))
		* CFrame.new(-center)
		* wheel.CFrame
end

-- Spins to land on segment `index`, easing out. Yields until done.
local function spin(wheel: BasePart, index: number)
	local segments = (wheel:GetAttribute("Segments") or 8) :: number
	local angle = (wheel:GetAttribute("Angle") or 0) :: number
	local size = 360 / segments
	local target = 90 - ((index - 1) * size + size / 2) -- that segment's middle under the pointer
	local delta = (target - angle) % 360 + 360 * Config.Lobby.WheelTurns
	local duration = Config.Lobby.WheelSpinTime
	local elapsed, applied = 0, 0
	while elapsed < duration do
		elapsed = math.min(elapsed + RunService.Heartbeat:Wait(), duration)
		local t = elapsed / duration
		local eased = 1 - (1 - t) ^ 3
		local wanted = delta * eased
		turn(wheel, wanted - applied)
		applied = wanted
	end
	wheel:SetAttribute("Angle", (angle + delta) % 360)
end

local function onTriggered(prompt: ProximityPrompt, player: Player)
	local model = prompt:FindFirstAncestorOfClass("Model")
	local wheel: BasePart? = nil
	for _, item in CollectionService:GetTagged("RewardWheel") do
		if item:IsA("BasePart") and model and item:IsDescendantOf(model) then
			wheel = item
		end
	end
	if not wheel or spinning[wheel] then
		return
	end
	local notify = Remotes.get("Notify")
	local cooldown = Config.Lobby.WheelCooldownHours * 3600
	local now = os.time()
	local waitLeft = lastSpinOf(player) + cooldown - now
	if waitLeft > 0 then
		notify:FireClient(player, `Next spin in {waitLeft // 3600}h {(waitLeft % 3600) // 60}m`)
		return
	end
	rememberSpin(player, now)
	local prizes = Config.Lobby.WheelPrizes
	local index = math.random(#prizes)
	spinning[wheel] = true
	prompt.Enabled = false
	spin(wheel, index)
	spinning[wheel] = nil
	prompt.Enabled = true
	notify:FireClient(player, `You won {prizes[index]}!`)
end

function RewardWheel.start()
	local function watch(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				onTriggered(prompt, player)
			end)
		end
	end
	for _, prompt in CollectionService:GetTagged("RewardWheelPrompt") do
		watch(prompt)
	end
	CollectionService:GetInstanceAddedSignal("RewardWheelPrompt"):Connect(watch)
end

return RewardWheel
