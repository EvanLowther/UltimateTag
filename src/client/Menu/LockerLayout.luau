--!strict
-- Where the Locker's pieces sit on any screen: the window, the info plate, the preview chip,
-- and the free space left for the 3D preview (client/LockerStage centres the character in it).
-- Everything is in virtual pixels (Ui.viewport, origin the menu's top-left corner under the top
-- bar) unless it says "real". Sizes are in Config.Locker. Three arrangements:
--   side:   the window docks left (WindowWidth), the plate sits top right, the chip bottom right,
--           the character is centred between the window and the plate. Used while that gap is
--           at least SideMinFree of the screen's width.
--   column: not enough room for that: the plate drops to the bottom right and the chip to the
--           top right, stacked above/below the character in the column beside the window.
--   sheet:  the column is under SheetMinColumn wide (a phone held upright): the window becomes
--           a sheet across the bottom, the chip and plate stack across the top, and the
--           character sits between them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent.Ui)

local LockerLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	mode: string, -- "side", "column" or "sheet"
	window: Rect,
	plate: Rect,
	chip: Rect,
	free: Rect, -- where the character should be fully visible
}

local MIN_FREE = 80 -- never plan for a free area smaller than this (virtual pixels)

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

-- The arrangement for a screen of `view` virtual pixels.
function LockerLayout.compute(view: Vector2): Layout
	local s = Config.Locker
	local width, height = view.X, view.Y
	local margin, edge, gap = s.WindowMargin, s.EdgeMargin, s.FreeGap
	local plate, chip = s.PlateSize, s.ChipSize
	local windowRight = margin + s.WindowWidth

	-- Side by side: window, character, plate.
	local plateLeft = width - edge - plate.X
	local freeLeft = windowRight + gap
	local freeRight = plateLeft - gap
	if freeRight - freeLeft >= s.SideMinFree * width then
		local top = edge
		local bottom = height - edge - chip.Y - gap
		return {
			mode = "side",
			window = rect(margin, 20, s.WindowWidth, height - 40),
			plate = rect(plateLeft, edge, plate.X, plate.Y),
			chip = rect(width - edge - chip.X, height - edge - chip.Y, chip.X, chip.Y),
			free = rect(freeLeft, top, freeRight - freeLeft, math.max(MIN_FREE, bottom - top)),
		}
	end

	-- Stacked in the column beside the window: chip on top, plate underneath.
	local column = width - edge - freeLeft
	if column >= s.SheetMinColumn then
		local plateWidth = math.min(plate.X, column)
		local chipWidth = math.min(chip.X, column)
		local plateY = height - edge - plate.Y
		local top = edge + chip.Y + gap / 2
		local bottom = plateY - gap
		return {
			mode = "column",
			window = rect(margin, 20, s.WindowWidth, height - 40),
			plate = rect(width - edge - plateWidth, plateY, plateWidth, plate.Y),
			chip = rect(width - edge - chipWidth, edge, chipWidth, chip.Y),
			free = rect(freeLeft, top, column, math.max(MIN_FREE, bottom - top)),
		}
	end

	-- A sheet across the bottom; the chip and the plate stack across the top.
	local sheetWidth = math.min(s.SheetMaxWidth, width - 2 * margin)
	local sheetHeight = s.SheetHeight * height
	local sheetTop = height - margin - sheetHeight
	local plateWidth = math.min(plate.X, width - 2 * edge)
	local chipWidth = math.min(chip.X, width - 2 * edge)
	local plateY = edge + chip.Y + gap / 2
	local top = plateY + plate.Y + gap / 2
	local bottom = sheetTop - gap / 2
	return {
		mode = "sheet",
		window = rect((width - sheetWidth) / 2, sheetTop, sheetWidth, sheetHeight),
		plate = rect(edge, plateY, plateWidth, plate.Y),
		chip = rect(edge, edge, chipWidth, chip.Y),
		free = rect(edge, top, width - 2 * edge, math.max(MIN_FREE, bottom - top)),
	}
end

-- The arrangement for the screen as it is now.
function LockerLayout.get(): Layout
	return LockerLayout.compute(Ui.viewport())
end

-- The free space in real pixels, in the camera's viewport (what the 3D preview is aimed at).
function LockerLayout.freeReal(): Rect
	local free = LockerLayout.get().free
	local factor = Ui.factor()
	local inset = Ui.inset()
	return rect(
		free.x * factor + inset.X,
		free.y * factor + inset.Y,
		free.w * factor,
		free.h * factor
	)
end

return LockerLayout
