--!strict
-- The dev panel's debug tools, all on this client only:
--   Fly:       fly through everything (WASD, E up, Q down, Shift faster). Holds MoveState.busy
--              so no move starts while flying.
--   Teleport:  Config.DevPanel.TeleportKey jumps you to where the mouse points.
--   Readout:   speed, vertical speed, current move, ground, humanoid state, sprint, role.
--   Spawns:    shows the loaded map's invisible spawn points.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.Parent.MoveState)
local Sprint = require(script.Parent.Parent.Sprint)
local Widgets = require(script.Parent.Widgets)

local DebugTools = {}

local player = Players.LocalPlayer

-- Fly ------------------------------------------------------------------------------------------

local flyStop: (() -> ())? = nil
local onFlyEnded: (() -> ())? = nil -- lets the panel turn its toggle off (respawn, death)

local function key(code: Enum.KeyCode): number
	return if UserInputService:IsKeyDown(code) then 1 else 0
end

function DebugTools.setFly(on: boolean)
	if flyStop then
		flyStop()
		flyStop = nil
	end
	if not on then
		return
	end
	local parts = MoveState.parts()
	if not parts then
		return
	end
	local hum, root, character = parts.humanoid, parts.root, parts.character
	local camera = workspace.CurrentCamera
	local settings = Config.DevPanel

	-- Noclip: remember which parts collided so they can be put back.
	local collided: { [BasePart]: boolean } = {}
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			collided[item] = item.CanCollide
		end
	end

	hum.PlatformStand = true
	local drive, removeDrive = MoveState.drive(root, false)
	local stepped = RunService.Stepped:Connect(function()
		for part in collided do
			part.CanCollide = false
		end
	end)
	local render = RunService.RenderStepped:Connect(function()
		MoveState.busy = "Fly"
		local look = camera.CFrame
		local input = look.LookVector * (key(Enum.KeyCode.W) - key(Enum.KeyCode.S))
			+ look.RightVector * (key(Enum.KeyCode.D) - key(Enum.KeyCode.A))
			+ Vector3.yAxis * (key(Enum.KeyCode.E) - key(Enum.KeyCode.Q))
		local speed = settings.FlySpeed
			* (if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then settings.FlyBoost else 1)
		drive.VectorVelocity = if input.Magnitude > 0 then input.Unit * speed else Vector3.zero
		local flat = Vector3.new(look.LookVector.X, 0, look.LookVector.Z)
		if flat.Magnitude > 1e-3 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
		root.AssemblyAngularVelocity = Vector3.zero
	end)
	local died = hum.Died:Connect(function()
		DebugTools.setFly(false)
		if onFlyEnded then
			onFlyEnded()
		end
	end)

	flyStop = function()
		render:Disconnect()
		stepped:Disconnect()
		died:Disconnect()
		removeDrive()
		for part, canCollide in collided do
			if part.Parent then
				part.CanCollide = canCollide
			end
		end
		if hum.Parent then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		if MoveState.busy == "Fly" then
			MoveState.busy = nil
		end
		MoveState.airVelocity = nil
	end
end

function DebugTools.onFlyEnded(callback: () -> ())
	onFlyEnded = callback
end

-- Teleport -------------------------------------------------------------------------------------

local teleportOn = false

function DebugTools.setTeleport(on: boolean)
	teleportOn = on
end

local function teleportToMouse()
	local parts = MoveState.parts()
	if not parts then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { parts.character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if not hit then
		return
	end
	local root = parts.root
	local facing = root.CFrame - root.Position
	parts.character:PivotTo(CFrame.new(hit.Position + Vector3.new(0, 4, 0)) * facing)
	root.AssemblyLinearVelocity = Vector3.zero
	MoveState.airVelocity = nil
end

-- Readout --------------------------------------------------------------------------------------

local readout: TextLabel? = nil
local readoutConnection: RBXScriptConnection? = nil

function DebugTools.setReadout(on: boolean, gui: ScreenGui)
	if readoutConnection then
		readoutConnection:Disconnect()
		readoutConnection = nil
	end
	if readout then
		readout:Destroy()
		readout = nil
	end
	if not on then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "Readout"
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 8, 1, -8)
	label.Size = UDim2.fromOffset(250, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundColor3 = Widgets.Colors.Window
	label.BackgroundTransparency = 0.25
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.RichText = true
	Widgets.text(label, 15)
	label.Font = Enum.Font.Code
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = label
	label.Parent = gui
	readout = label

	readoutConnection = RunService.RenderStepped:Connect(function()
		local parts = MoveState.parts()
		if not parts then
			label.Text = "no character"
			return
		end
		local v = parts.root.AssemblyLinearVelocity
		local p = parts.root.Position
		local lines = {
			string.format("speed     %5.1f", MoveState.flat(v).Magnitude),
			string.format("vertical  %5.1f", v.Y),
			`move      {MoveState.busy or "-"}`,
			`ground    {if MoveState.isGrounded(parts.humanoid) then "yes" else "no"}`,
			`state     {parts.humanoid:GetState().Name}`,
			`sprint    {if Sprint.isSprinting() then "yes" else "no"}`,
			string.format("walkspeed %5.1f", parts.humanoid.WalkSpeed),
			`role      {player:GetAttribute("Role") or "-"}`,
			string.format("position  %.0f, %.0f, %.0f", p.X, p.Y, p.Z),
		}
		label.Text = table.concat(lines, "\n")
	end)
end

-- Spawn points ---------------------------------------------------------------------------------

local spawnsOn = false

local function showSpawns(map: Instance?)
	local folder = map and map:FindFirstChild("Spawns")
	if not folder then
		return
	end
	for _, point in folder:GetChildren() do
		if point:IsA("BasePart") then
			point.Transparency = if spawnsOn then 0.35 else 1
			point.Material = Enum.Material.Neon
		end
	end
end

function DebugTools.setSpawns(on: boolean)
	spawnsOn = on
	showSpawns(workspace:FindFirstChild("ActiveMap"))
end

function DebugTools.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and teleportOn and input.KeyCode == Config.DevPanel.TeleportKey then
			teleportToMouse()
		end
	end)
	-- A newly loaded map shows its spawn points too while that's on.
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" and spawnsOn then
			child:WaitForChild("Spawns", 5)
			showSpawns(child)
		end
	end)
	-- Respawning ends a flight.
	player.CharacterAdded:Connect(function()
		if flyStop then
			DebugTools.setFly(false)
			if onFlyEnded then
				onFlyEnded()
			end
		end
	end)
end

return DebugTools
