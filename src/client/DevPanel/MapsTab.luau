--!strict
-- Dev panel, Maps tab: every map in ServerStorage.Maps (the server sends the list) with its
-- player range and spawn count. Play loads it and puts you (or everyone) on its spawn points;
-- Next round makes the next game round use it. Also: unload the map, go to the lobby, show
-- spawn points.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local DebugTools = require(script.Parent.DebugTools)
local Widgets = require(script.Parent.Widgets)

local MapsTab = {}

type MapInfo = {
	Name: string,
	DisplayName: string,
	MinPlayers: number,
	MaxPlayers: number,
	InRotation: boolean,
	Spawns: number,
}

local function goToLobby()
	local lobby = workspace:FindFirstChild("Lobby")
	local spawn = lobby and lobby:FindFirstChild("LobbySpawn", true)
	local character = Players.LocalPlayer.Character
	if spawn and spawn:IsA("BasePart") and character then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

-- Returns a function the panel calls to ask the server for a fresh list.
function MapsTab.build(page: Instance, send: (string, ...any) -> ()): () -> ()
	Widgets.section(page, "Maps")
	local header = Widgets.label(page, "Loading...")
	local list = Widgets.list(page, 6)

	Widgets.section(page, "Tools")
	local tools = Widgets.row(page)
	Widgets.button(tools, "Next: automatic", function()
		send("NextMap", nil)
	end)
	Widgets.button(tools, "Unload map", function()
		send("UnloadMap")
	end)
	local more = Widgets.row(page)
	Widgets.button(more, "Go to lobby", goToLobby)
	Widgets.button(more, "Refresh", function()
		send("ListMaps")
	end)
	Widgets.toggle(page, "Show spawn points", false, DebugTools.setSpawns)

	local function show(maps: { MapInfo }, active: string?, nextMap: string?)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		header.Text =
			`Loaded: <b>{active or "none"}</b>   Next round: <b>{nextMap or "automatic"}</b>`
		for _, map in maps do
			local card = Widgets.list(list, 3)
			local tier = if map.InRotation
				then `{map.MinPlayers}-{map.MaxPlayers} players`
				else "not in rotation"
			local title = Widgets.label(
				card,
				`<b>{map.DisplayName}</b>  ({map.Name})  {tier}, {map.Spawns} spawns`
			)
			if map.Name == active then
				title.TextColor3 = Widgets.Colors.On
			elseif map.Name == nextMap then
				title.TextColor3 = Widgets.Colors.Changed
			end
			local buttons = Widgets.row(card)
			Widgets.button(buttons, "Play", function()
				send("PlayMap", map.Name, false)
			end)
			Widgets.button(buttons, "Play (all)", function()
				send("PlayMap", map.Name, true)
			end)
			Widgets.button(buttons, "Next round", function()
				send("NextMap", map.Name)
			end)
		end
	end

	Remotes.get("DevCommand").OnClientEvent:Connect(function(kind, maps, active, nextMap)
		if kind == "Maps" then
			show(maps, active, nextMap)
		end
	end)

	return function()
		send("ListMaps")
	end
end

return MapsTab
