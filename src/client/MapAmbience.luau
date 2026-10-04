--!strict
-- Small moving touches that make a map feel alive, from part attributes (client only, so each
-- player just sees them; nothing here affects gameplay):
--   Flicker (true): a light that cuts out now and then for a moment (its Neon and any light in it).
--   Spin (number, degrees per second): turns the part around the world's up axis (ceiling fans).
-- Looks at the loaded map (Workspace.ActiveMap) whenever one is loaded.
local RunService = game:GetService("RunService")

local MapAmbience = {}

type Flicker = { part: BasePart, material: Enum.Material, lights: { Light }, nextAt: number }
type Spinner = { part: BasePart, base: CFrame, rate: number, angle: number }

local flickers: { Flicker } = {}
local spinners: { Spinner } = {}

local function setLit(flicker: Flicker, lit: boolean)
	flicker.part.Material = if lit then flicker.material else Enum.Material.SmoothPlastic
	for _, light in flicker.lights do
		light.Enabled = lit
	end
end

-- A short burst of cutting out and back on.
local function flick(flicker: Flicker)
	task.spawn(function()
		for _ = 1, math.random(2, 4) do
			setLit(flicker, false)
			task.wait(math.random() * 0.08 + 0.03)
			setLit(flicker, true)
			task.wait(math.random() * 0.15 + 0.04)
		end
	end)
end

local function scan(map: Instance)
	table.clear(flickers)
	table.clear(spinners)
	local now = os.clock()
	for _, item in map:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		if item:GetAttribute("Flicker") == true then
			local lights = {}
			for _, child in item:GetChildren() do
				if child:IsA("Light") then
					table.insert(lights, child)
				end
			end
			table.insert(flickers, {
				part = item,
				material = item.Material,
				lights = lights,
				nextAt = now + math.random() * 4,
			})
		end
		local rate = item:GetAttribute("Spin")
		if type(rate) == "number" then
			table.insert(spinners, { part = item, base = item.CFrame, rate = rate, angle = 0 })
		end
	end
end

function MapAmbience.start()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" then
			task.wait(0.5) -- let it finish replicating
			if child.Parent then
				scan(child)
			end
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "ActiveMap" then
			table.clear(flickers)
			table.clear(spinners)
		end
	end)
	local current = workspace:FindFirstChild("ActiveMap")
	if current then
		scan(current)
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, spinner in spinners do
			if spinner.part.Parent then
				spinner.angle = (spinner.angle + spinner.rate * dt) % 360
				local base = spinner.base
				spinner.part.CFrame = CFrame.new(base.Position)
					* CFrame.Angles(0, math.rad(spinner.angle), 0)
					* base.Rotation
			end
		end
		local now = os.clock()
		for _, flicker in flickers do
			if now >= flicker.nextAt and flicker.part.Parent then
				flicker.nextAt = now + 2 + math.random() * 6
				flick(flicker)
			end
		end
	end)
end

return MapAmbience
