--!strict
-- The tags over heads (shared/TitleTag's titles, server/Bots' BOT name tags) are drawn at a
-- fixed size in pixels, so when their character is far away and tiny the tag would stay just as
-- big and cover the screen. Every frame this scales each one's "Content" frame by how far it is
-- from the camera: full size within Config.HeadTags.FullSizeWithin studs (never bigger than it
-- was designed), smaller further away the way the character gets smaller, down to Smallest.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local HeadTags = {}

local tags: { [BillboardGui]: UIScale } = {}

local function watch(item: Instance)
	if not item:IsA("BillboardGui") or not Config.HeadTags.Names[item.Name] then
		return
	end
	local content = item:WaitForChild("Content", 5)
	if not content or not item.Parent then
		return
	end
	local scale = content:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = content
	tags[item] = scale :: UIScale
end

function HeadTags.start()
	workspace.DescendantAdded:Connect(function(item)
		if item:IsA("BillboardGui") then
			task.spawn(watch, item)
		end
	end)
	for _, item in workspace:GetDescendants() do
		if item:IsA("BillboardGui") then
			task.spawn(watch, item)
		end
	end
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local settings = Config.HeadTags
		local eye = camera.CFrame.Position
		for gui, scale in tags do
			local part = gui.Adornee or gui.Parent
			if not gui.Parent or not part then
				tags[gui] = nil
				continue
			end
			if part:IsA("BasePart") then
				local distance = (part.Position - eye).Magnitude
				local wanted = math.clamp(
					settings.FullSizeWithin / math.max(distance, 0.1),
					settings.Smallest,
					1
				)
				if math.abs(scale.Scale - wanted) > 0.005 then
					scale.Scale = wanted
				end
			end
		end
	end)
end

return HeadTags
