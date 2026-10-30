--!strict
-- Turns the player's controls (Roblox's PlayerModule: move, jump) off while something else owns
-- them, and back on when nothing does. Each owner ("Spectate", "WinScreen") sets and clears its
-- own lock; the controls stay off while any lock is held. `apply` re-applies the state after
-- something else (the Locker's preview) switched the controls on behind our back.
local Players = game:GetService("Players")

local ControlLock = {}

local owners: { [string]: boolean } = {}
local cached: any = nil

local function controls(): any
	if cached then
		return cached
	end
	local ok, module = pcall(function()
		return require(
			Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript
		) :: any
	end)
	if ok and module then
		cached = module:GetControls()
	end
	return cached
end

-- Makes the controls match the locks held right now.
function ControlLock.apply()
	local playerControls = controls()
	if not playerControls then
		return
	end
	if next(owners) ~= nil then
		playerControls:Disable()
	else
		playerControls:Enable()
	end
end

function ControlLock.set(owner: string, locked: boolean)
	local was = owners[owner] == true
	owners[owner] = if locked then true else nil
	if was ~= locked then
		ControlLock.apply()
	end
end

function ControlLock.isLocked(): boolean
	return next(owners) ~= nil
end

return ControlLock
