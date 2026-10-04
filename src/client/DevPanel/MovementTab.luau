--!strict
-- Dev panel, Movement tab: a slider for every value in Config.DevPanel.Tunables. Changes apply
-- at once to this client's Config (the moves read it live) and to the server's (walk speeds,
-- tag range). They last until the playtest stops: "Copy changes" lists them for Config.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Widgets = require(script.Parent.Widgets)

local MovementTab = {}

type Row = {
	section: string,
	key: string,
	step: number,
	default: number,
	slider: Widgets.Slider,
}

function MovementTab.build(page: Instance, send: (string, ...any) -> ())
	local values = Config :: any
	local rows: { Row } = {}

	local tools = Widgets.row(page)
	local output: TextBox

	local function changes(): { string }
		local lines = {}
		for _, row in rows do
			local now = values[row.section][row.key]
			if now ~= row.default then
				table.insert(
					lines,
					`{row.section}.{row.key} = {Widgets.formatStep(now, row.step)} -- was {row.default}`
				)
			end
		end
		return lines
	end

	Widgets.button(tools, "Copy changes", function()
		local lines = changes()
		local text = if #lines > 0 then table.concat(lines, "\n") else "No changes"
		output.Text = text
		output.Visible = true
		print(`[DevPanel] Movement changes (paste into Config.luau):\n{text}`)
	end)
	Widgets.button(tools, "Reset all", function()
		for _, row in rows do
			values[row.section][row.key] = row.default
			row.slider.set(row.default)
			row.slider.setChanged(false)
			send("SetTunable", row.section, row.key, row.default)
		end
		output.Visible = false
	end)

	output = Instance.new("TextBox")
	output.Visible = false
	output.BackgroundColor3 = Widgets.Colors.Bar
	output.Size = UDim2.fromScale(1, 0)
	output.AutomaticSize = Enum.AutomaticSize.Y
	output.MultiLine = true
	output.TextWrapped = true
	output.ClearTextOnFocus = false
	output.TextEditable = false
	output.TextXAlignment = Enum.TextXAlignment.Left
	output.LayoutOrder = Widgets.nextOrder()
	Widgets.text(output, 13)
	output.Font = Enum.Font.Code
	output.Parent = page
	Widgets.label(page, "Also printed to the Output window. Select the text and copy it.")

	local lastSection = ""
	for _, entry in Config.DevPanel.Tunables do
		local section, key, min, max, step = entry[1], entry[2], entry[3], entry[4], entry[5]
		local current = values[section] and values[section][key]
		if type(current) ~= "number" then
			warn(`[DevPanel] Config.{section}.{key} is not a number`)
			continue
		end
		if section ~= lastSection then
			Widgets.section(page, section)
			lastSection = section
		end
		local row: Row
		local slider = Widgets.slider(page, key, min, max, step, current, function(value)
			values[section][key] = value
			row.slider.setChanged(value ~= row.default)
			send("SetTunable", section, key, value)
		end)
		row = { section = section, key = key, step = step, default = current, slider = slider }
		table.insert(rows, row)
	end
end

return MovementTab
