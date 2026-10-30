--!strict
-- The game's icons, drawn in code from flat shapes (no images, no emoji), in the Street sprint
-- style: bold and geometric, a main color plus an accent. Icons.draw(parent, name, size,
-- color, accent) returns a square Frame holding the icon; it works anywhere a GuiObject can go:
-- menus, buttons, and BillboardGuis in the world (the Hearts, Stars and Pow tag effects, the
-- victory stars). Icons.paint recolors one.
--   Shapes: boxes (optionally rounded or turned), circles, rings, lines, arcs (short
--   round-ended lines), right triangles (a box cut along its diagonal by a UIGradient with a
--   hard transparency step, like the menu's slanted edges) which build peaks, arrowheads,
--   diamonds, sparkle stars and teardrops, and a Bangers glyph (the crate's question mark).
--   Turned shapes are drawn inside a turned holder frame.
local Icons = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(17, 17, 17)
local DISPLAY = Font.new("rbxasset://fonts/families/Bangers.json")

local function kp(t: number, v: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(t, v)
end
local KEEP_HIGH = NumberSequence.new({ kp(0, 1), kp(0.495, 1), kp(0.505, 0), kp(1, 0) })
local KEEP_LOW = NumberSequence.new({ kp(0, 0), kp(0.495, 0), kp(0.505, 1), kp(1, 1) })

type Canvas = { frame: Frame, size: number, color: Color3, accent: Color3 }

-- A shape in the icon's main color or its accent (Icons.paint uses the role).
local function shape(c: Canvas, accent: boolean?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = if accent then c.accent else c.color
	f:SetAttribute("IconRole", if accent then "accent" else "main")
	f.Parent = c.frame
	return f
end

local function round(f: Frame, amount: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(amount * 0.5, 0)
	corner.Parent = f
end

-- A see-through square `scale` of the icon wide, centered at (cx, cy) and turned `rotation`
-- degrees: a canvas of its own for drawing turned shapes.
local function holder(c: Canvas, rotation: number, scale: number?, cx: number?, cy: number?): Canvas
	local s = scale or 1
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx or 0.5, cy or 0.5)
	f.Size = UDim2.fromScale(s, s)
	f.Rotation = rotation
	f.Parent = c.frame
	return { frame = f, size = c.size * s, color = c.color, accent = c.accent }
end

-- A box at (x, y) sized (w, h), in fractions of the icon. `rounding` 0-1 (1: round ends),
-- `rotation` in degrees about its middle.
local function box(
	c: Canvas,
	x: number,
	y: number,
	w: number,
	h: number,
	accent: boolean?,
	rounding: number?,
	rotation: number?
): Frame
	local f = shape(c, accent)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x + w / 2, y + h / 2)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rotation or 0
	if rounding and rounding > 0 then
		round(f, rounding)
	end
	return f
end

local function circle(c: Canvas, cx: number, cy: number, r: number, accent: boolean?): Frame
	return box(c, cx - r, cy - r, r * 2, r * 2, accent, 1)
end

-- A ring of radius r (to the middle of its band), `thick` wide.
local function ring(
	c: Canvas,
	cx: number,
	cy: number,
	r: number,
	thick: number,
	accent: boolean?
): Frame
	local inner = r - thick / 2
	local f = box(c, cx - inner, cy - inner, inner * 2, inner * 2, accent, 1)
	f.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = f.BackgroundColor3
	stroke.Thickness = math.max(1, thick * c.size)
	stroke:SetAttribute("IconRole", f:GetAttribute("IconRole"))
	stroke.Parent = f
	return f
end

-- A bar from (x1, y1) to (x2, y2), `thick` wide, with round ends if `rounded`.
local function line(
	c: Canvas,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	thick: number,
	accent: boolean?,
	rounded: boolean?
): Frame
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy) + (if rounded then thick else 0)
	local f = shape(c, accent)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2)
	f.Size = UDim2.fromScale(length, thick)
	f.Rotation = math.deg(math.atan2(dy, dx))
	if rounded then
		round(f, 1)
	end
	return f
end

-- An arc of radius r round (cx, cy) from angle a0 to a1 (degrees, clockwise from the right),
-- `thick` wide, made of short round-ended lines. Returns where it ends.
local function arc(
	c: Canvas,
	cx: number,
	cy: number,
	r: number,
	a0: number,
	a1: number,
	thick: number,
	accent: boolean?,
	steps: number?
): (number, number)
	local count = steps or math.max(3, math.floor(math.abs(a1 - a0) / 22))
	local x, y = cx + math.cos(math.rad(a0)) * r, cy + math.sin(math.rad(a0)) * r
	for i = 1, count do
		local a = math.rad(a0 + (a1 - a0) * i / count)
		local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
		line(c, x, y, nx, ny, thick, accent, true)
		x, y = nx, ny
	end
	return x, y
end

-- A right triangle filling half of the box (x, y, w, h): the half with its right angle at
-- `corner` ("TL", "TR", "BL" or "BR").
local function tri(
	c: Canvas,
	x: number,
	y: number,
	w: number,
	h: number,
	corner: string,
	accent: boolean?
): Frame
	-- A hair of overlap so shapes made of several triangles don't show seams.
	local f = box(c, x - 0.002, y - 0.002, w + 0.004, h + 0.004, accent)
	local angle = math.deg(math.atan(w / h))
	local cut = Instance.new("UIGradient")
	if corner == "TL" then
		cut.Rotation, cut.Transparency = angle, KEEP_LOW
	elseif corner == "BR" then
		cut.Rotation, cut.Transparency = angle, KEEP_HIGH
	elseif corner == "BL" then
		cut.Rotation, cut.Transparency = -angle, KEEP_LOW
	else -- TR
		cut.Rotation, cut.Transparency = -angle, KEEP_HIGH
	end
	cut.Parent = f
	return f
end

-- A triangle pointing up (apex at the top middle of the box).
local function peak(c: Canvas, x: number, y: number, w: number, h: number, accent: boolean?)
	tri(c, x, y, w / 2, h, "BR", accent)
	tri(c, x + w / 2, y, w / 2, h, "BL", accent)
end

-- A triangle pointing down.
local function vee(c: Canvas, x: number, y: number, w: number, h: number, accent: boolean?)
	tri(c, x, y, w / 2, h, "TR", accent)
	tri(c, x + w / 2, y, w / 2, h, "TL", accent)
end

-- A diamond centered at (cx, cy) reaching rw sideways and rh up and down.
local function rhombus(c: Canvas, cx: number, cy: number, rw: number, rh: number, accent: boolean?)
	tri(c, cx, cy - rh, rw, rh, "BL", accent)
	tri(c, cx - rw, cy - rh, rw, rh, "BR", accent)
	tri(c, cx - rw, cy, rw, rh, "TR", accent)
	tri(c, cx, cy, rw, rh, "TL", accent)
end

-- A four-point sparkle star.
local function sparkle(c: Canvas, cx: number, cy: number, r: number, accent: boolean?)
	rhombus(c, cx, cy, r * 0.28, r, accent)
	rhombus(c, cx, cy, r, r * 0.28, accent)
end

-- A filled arrowhead `size` long, the middle of its base at (x, y), pointing along
-- `direction` (degrees, clockwise from the right): the end of an arc arrow.
local function arrowhead(
	c: Canvas,
	x: number,
	y: number,
	direction: number,
	size: number,
	accent: boolean?
)
	local a = math.rad(direction)
	local h = holder(
		c,
		direction + 90,
		size,
		x + math.cos(a) * size * 0.45,
		y + math.sin(a) * size * 0.45
	)
	peak(h, 0, 0.05, 1, 0.9, accent)
end

-- A teardrop (a flame's tongue): a circle of radius r round (cx, cy) and a point d above its
-- center (d up to 2r), the point's sides running onto the circle. `tilt` leans it (degrees).
local function drop(
	c: Canvas,
	cx: number,
	cy: number,
	r: number,
	d: number,
	accent: boolean?,
	tilt: number?
)
	local s = 2 * d + 0.04
	local h = holder(c, tilt or 0, s, cx, cy)
	local rr, dd = r / s, d / s
	circle(h, 0.5, 0.5, rr, accent)
	-- The point's sides touch the circle where they meet it (tangents from the tip).
	local cosA = rr / dd
	local half = rr * math.sqrt(1 - cosA * cosA)
	peak(h, 0.5 - half, 0.5 - dd, half * 2, dd - rr * cosA, accent)
end

-- A character in Bangers (the crate's question mark), `size` tall, centered at (cx, cy).
local function glyph(
	c: Canvas,
	text: string,
	cx: number,
	cy: number,
	size: number,
	accent: boolean?
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(cx, cy)
	label.Size = UDim2.fromScale(size, size)
	label.Text = text
	label.TextScaled = true
	label.FontFace = DISPLAY
	label.TextColor3 = if accent then c.accent else c.color
	label:SetAttribute("IconRole", if accent then "accent" else "main")
	label.Parent = c.frame
	return label
end

-- A small gold coin with a "C" (the coin icons).
local function coinAt(c: Canvas, cx: number, cy: number, r: number)
	local gold = Color3.fromRGB(255, 214, 10)
	local edge = Color3.fromRGB(170, 120, 0)
	local rim = circle(c, cx, cy, r, true)
	rim.BackgroundColor3 = edge
	rim:SetAttribute("IconRole", "fixed")
	local face = circle(c, cx, cy, r * 0.84, true)
	face.BackgroundColor3 = gold
	face:SetAttribute("IconRole", "fixed")
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(cx, cy)
	mark.Size = UDim2.fromScale(r * 1.6, r * 1.6)
	mark.Text = "C"
	mark.TextScaled = true
	mark.FontFace = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Heavy)
	mark.TextColor3 = Color3.fromRGB(150, 100, 0)
	mark.Parent = c.frame
end

-- A block figure (the victory icons): head, body, legs, and arms from `arms`, each a list of
-- line points.
local function figure(c: Canvas, arms: { { number } }, offsetY: number?)
	local y = offsetY or 0
	box(c, 0.42, 0.1 + y, 0.16, 0.16, false, 0.3)
	box(c, 0.4, 0.29 + y, 0.2, 0.3, false, 0.15)
	box(c, 0.405, 0.6 + y, 0.085, 0.3, false, 0.3)
	box(c, 0.51, 0.6 + y, 0.085, 0.3, false, 0.3)
	for _, arm in arms do
		line(c, arm[1], arm[2] + y, arm[3], arm[4] + y, 0.085, false, true)
	end
end

local CHEER_ARMS = { { 0.42, 0.33, 0.22, 0.1 }, { 0.58, 0.33, 0.78, 0.1 } }

local DRAW: { [string]: (Canvas) -> () } = {
	-- Menu pages.
	shop = function(c)
		box(c, 0.16, 0.36, 0.68, 0.56, false, 0.18)
		arc(c, 0.5, 0.38, 0.17, 180, 360, 0.08, false, 6)
		box(c, 0.16, 0.52, 0.68, 0.09, true)
	end,
	locker = function(c)
		box(c, 0.22, 0.06, 0.56, 0.88, false, 0.12)
		for _, y in { 0.17, 0.27, 0.37 } do
			box(c, 0.33, y, 0.34, 0.05, true, 1)
		end
		box(c, 0.58, 0.56, 0.08, 0.18, true, 1)
	end,
	quests = function(c)
		ring(c, 0.5, 0.5, 0.38, 0.11)
		ring(c, 0.5, 0.5, 0.21, 0.11)
		circle(c, 0.5, 0.5, 0.08, true)
	end,
	rewards = function(c)
		box(c, 0.14, 0.44, 0.72, 0.46, false, 0.08)
		box(c, 0.08, 0.3, 0.84, 0.16, false, 0.08)
		box(c, 0.44, 0.3, 0.12, 0.6, true)
		box(c, 0.29, 0.12, 0.17, 0.17, true, 0.4, 45)
		box(c, 0.54, 0.12, 0.17, 0.17, true, 0.4, 45)
	end,
	leaders = function(c)
		box(c, 0.36, 0.32, 0.28, 0.6, false)
		box(c, 0.06, 0.5, 0.28, 0.42, false)
		box(c, 0.66, 0.62, 0.28, 0.3, false)
		sparkle(c, 0.5, 0.17, 0.11, true)
	end,
	-- Small marks.
	check = function(c)
		line(c, 0.2, 0.52, 0.42, 0.74, 0.15, false, true)
		line(c, 0.42, 0.74, 0.82, 0.28, 0.15, false, true)
	end,
	close = function(c)
		line(c, 0.24, 0.24, 0.76, 0.76, 0.15, false, true)
		line(c, 0.76, 0.24, 0.24, 0.76, 0.15, false, true)
	end,
	lock = function(c)
		box(c, 0.3, 0.12, 0.09, 0.36, false)
		box(c, 0.61, 0.12, 0.09, 0.36, false)
		box(c, 0.3, 0.1, 0.4, 0.09, false, 0.6)
		box(c, 0.18, 0.42, 0.64, 0.5, false, 0.2)
		circle(c, 0.5, 0.6, 0.075, true)
		box(c, 0.465, 0.62, 0.07, 0.15, true)
	end,
	play = function(c)
		tri(c, 0.24, 0.12, 0.58, 0.38, "BL")
		tri(c, 0.24, 0.5, 0.58, 0.38, "TL")
	end,
	dash = function(c)
		box(c, 0.2, 0.44, 0.6, 0.12, false, 1)
	end,
	bolt = function(c)
		line(c, 0.62, 0.06, 0.36, 0.5, 0.15, false)
		box(c, 0.3, 0.43, 0.42, 0.14, false)
		line(c, 0.64, 0.5, 0.38, 0.94, 0.15, false)
	end,
	clock = function(c)
		ring(c, 0.5, 0.55, 0.36, 0.1)
		line(c, 0.5, 0.55, 0.5, 0.33, 0.08, true, true)
		line(c, 0.5, 0.55, 0.66, 0.62, 0.08, true, true)
		box(c, 0.43, 0.05, 0.14, 0.1, false, 0.3)
	end,
	flame = function(c)
		drop(c, 0.56, 0.64, 0.27, 0.56, false, 12)
		drop(c, 0.31, 0.71, 0.18, 0.4, false, -24)
		drop(c, 0.52, 0.74, 0.14, 0.3, true, 6)
	end,
	crate = function(c)
		box(c, 0.06, 0.12, 0.88, 0.22, false, 0.18) -- the lid
		box(c, 0.12, 0.38, 0.76, 0.52, false, 0.14)
		box(c, 0.43, 0.27, 0.14, 0.14, true, 0.3) -- the latch
		glyph(c, "?", 0.5, 0.65, 0.46, true)
	end,
	-- Quest and achievement icons.
	trophy = function(c)
		box(c, 0.28, 0.12, 0.44, 0.26, false)
		circle(c, 0.5, 0.36, 0.22)
		ring(c, 0.27, 0.3, 0.1, 0.06)
		ring(c, 0.73, 0.3, 0.1, 0.06)
		box(c, 0.45, 0.56, 0.1, 0.16, false)
		box(c, 0.3, 0.72, 0.4, 0.08, false, 0.3)
		box(c, 0.24, 0.8, 0.52, 0.1, false, 0.3)
		sparkle(c, 0.5, 0.32, 0.09, true)
	end,
	burst = function(c)
		-- A comic impact star: long and short spikes round a middle, a smaller accent star
		-- inside.
		for i = 0, 3 do
			rhombus(holder(c, i * 45 + 22.5), 0.5, 0.5, 0.075, if i % 2 == 0 then 0.47 else 0.36)
			rhombus(holder(c, i * 45), 0.5, 0.5, 0.06, if i % 2 == 0 then 0.3 else 0.24)
		end
		circle(c, 0.5, 0.5, 0.2)
		for i = 0, 3 do
			rhombus(holder(c, i * 45 + 22.5), 0.5, 0.5, 0.045, 0.2, true)
		end
		circle(c, 0.5, 0.5, 0.1, true)
	end,
	sparks = function(c)
		for i = 0, 5 do
			local a = math.rad(i * 60)
			line(
				c,
				0.5 + math.cos(a) * 0.2,
				0.5 + math.sin(a) * 0.2,
				0.5 + math.cos(a) * 0.44,
				0.5 + math.sin(a) * 0.44,
				0.08,
				i % 2 == 1,
				true
			)
		end
		sparkle(c, 0.5, 0.5, 0.16, false)
	end,
	gamepad = function(c)
		box(c, 0.08, 0.3, 0.84, 0.42, false, 0.6)
		box(c, 0.2, 0.47, 0.2, 0.07, true)
		box(c, 0.265, 0.405, 0.07, 0.2, true)
		circle(c, 0.66, 0.46, 0.055, true)
		circle(c, 0.77, 0.56, 0.055, true)
	end,
	shield = function(c)
		box(c, 0.2, 0.1, 0.6, 0.46, false, 0.15)
		box(c, 0.29, 0.38, 0.42, 0.42, false, 0.1, 45)
		box(c, 0.45, 0.16, 0.1, 0.64, true, 0.5)
	end,
	wall = function(c)
		for row, y in { 0.16, 0.41, 0.66 } do
			if row % 2 == 1 then
				box(c, 0.06, y, 0.42, 0.19, false, 0.15)
				box(c, 0.52, y, 0.42, 0.19, false, 0.15)
			else
				box(c, 0.06, y, 0.2, 0.19, false, 0.15)
				box(c, 0.3, y, 0.4, 0.19, false, 0.15)
				box(c, 0.74, y, 0.2, 0.19, false, 0.15)
			end
		end
	end,
	ladder = function(c)
		box(c, 0.24, 0.06, 0.09, 0.88, false, 0.5)
		box(c, 0.67, 0.06, 0.09, 0.88, false, 0.5)
		for _, y in { 0.2, 0.4, 0.6, 0.8 } do
			box(c, 0.28, y - 0.035, 0.44, 0.07, true)
		end
	end,
	speed = function(c)
		box(c, 0.1, 0.22, 0.62, 0.11, false, 1)
		box(c, 0.26, 0.445, 0.66, 0.11, true, 1)
		box(c, 0.16, 0.67, 0.5, 0.11, false, 1)
	end,
	vault = function(c)
		-- A hurdle with an arrow arcing over it.
		box(c, 0.3, 0.64, 0.08, 0.28, false)
		box(c, 0.62, 0.64, 0.08, 0.28, false)
		box(c, 0.22, 0.58, 0.56, 0.1, false, 0.5)
		local x, y = arc(c, 0.5, 0.62, 0.34, 190, 320, 0.09, true)
		arrowhead(c, x, y, 410, 0.2, true)
	end,
	chart = function(c)
		box(c, 0.12, 0.6, 0.18, 0.3, false, 0.2)
		box(c, 0.41, 0.42, 0.18, 0.48, false, 0.2)
		box(c, 0.7, 0.18, 0.18, 0.72, false, 0.2)
		box(c, 0.08, 0.9, 0.84, 0.05, true)
	end,
	crown = function(c)
		peak(c, 0.12, 0.26, 0.26, 0.4)
		peak(c, 0.37, 0.14, 0.26, 0.52)
		peak(c, 0.62, 0.26, 0.26, 0.4)
		box(c, 0.12, 0.62, 0.76, 0.2, false, 0.2)
		circle(c, 0.5, 0.72, 0.06, true)
		circle(c, 0.3, 0.72, 0.045, true)
		circle(c, 0.7, 0.72, 0.045, true)
	end,
	gem = function(c)
		box(c, 0.3, 0.2, 0.4, 0.18, false)
		tri(c, 0.14, 0.2, 0.16, 0.18, "BR")
		tri(c, 0.7, 0.2, 0.16, 0.18, "BL")
		vee(c, 0.14, 0.38, 0.72, 0.46)
		vee(c, 0.36, 0.38, 0.28, 0.3, true)
		tri(c, 0.36, 0.2, 0.14, 0.18, "BR", true)
	end,
	-- Coins.
	coin = function(c)
		coinAt(c, 0.5, 0.5, 0.36)
	end,
	coins2 = function(c)
		coinAt(c, 0.38, 0.6, 0.28)
		coinAt(c, 0.62, 0.42, 0.28)
	end,
	coins3 = function(c)
		coinAt(c, 0.3, 0.64, 0.24)
		coinAt(c, 0.7, 0.64, 0.24)
		coinAt(c, 0.5, 0.36, 0.24)
	end,
	coinPile = function(c)
		for _, spot in
			{
				{ 0.22, 0.72 },
				{ 0.5, 0.72 },
				{ 0.78, 0.72 },
				{ 0.36, 0.48 },
				{ 0.64, 0.48 },
				{ 0.5, 0.25 },
			}
		do
			coinAt(c, spot[1], spot[2], 0.17)
		end
	end,
	coin2x = function(c)
		coinAt(c, 0.42, 0.55, 0.32)
		local badge = box(c, 0.56, 0.1, 0.38, 0.28, true, 0.4)
		badge:SetAttribute("IconRole", "fixed")
		badge.BackgroundColor3 = Color3.fromRGB(255, 46, 136)
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = "2X"
		text.TextScaled = true
		text.FontFace =
			Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Heavy)
		text.TextColor3 = WHITE
		text.Parent = badge
	end,
	-- Tag effects.
	heart = function(c)
		circle(c, 0.33, 0.37, 0.2)
		circle(c, 0.67, 0.37, 0.2)
		box(c, 0.265, 0.3, 0.47, 0.47, false, 0.08, 45)
	end,
	sparkle = function(c)
		sparkle(c, 0.46, 0.54, 0.4)
		sparkle(c, 0.8, 0.18, 0.13, true)
	end,
	ring = function(c)
		ring(c, 0.5, 0.5, 0.35, 0.13)
	end,
	shockwave = function(c)
		ring(c, 0.5, 0.5, 0.4, 0.07)
		ring(c, 0.5, 0.5, 0.26, 0.07, true)
		circle(c, 0.5, 0.5, 0.1)
	end,
	confetti = function(c)
		local pieces = {
			{ 0.2, 0.22, 20, Color3.fromRGB(255, 210, 60) },
			{ 0.62, 0.16, -30, Color3.fromRGB(255, 90, 90) },
			{ 0.42, 0.44, 50, Color3.fromRGB(170, 80, 255) },
			{ 0.74, 0.5, 15, Color3.fromRGB(25, 227, 255) },
			{ 0.18, 0.64, -45, Color3.fromRGB(124, 255, 79) },
			{ 0.52, 0.74, 30, Color3.fromRGB(255, 46, 136) },
		}
		for _, p in pieces do
			local piece = box(c, p[1], p[2], 0.16, 0.09, false, 0.2, p[3])
			piece.BackgroundColor3 = p[4]
			piece:SetAttribute("IconRole", "fixed")
		end
	end,
	meteor = function(c)
		-- A comet: a wide tail and two thin streaks fading away from the head.
		for _, streak in
			{
				{ 0.66, 0.34, 0.12, 0.88, 0.26 },
				{ 0.77, 0.43, 0.46, 0.84, 0.07 },
				{ 0.53, 0.23, 0.16, 0.54, 0.07 },
			}
		do
			local tail = line(c, streak[1], streak[2], streak[3], streak[4], streak[5], true, true)
			local fade = Instance.new("UIGradient")
			fade.Transparency = NumberSequence.new(0, 1) -- solid at the head end (the start)
			fade.Parent = tail
		end
		circle(c, 0.66, 0.34, 0.2)
	end,
	shards = function(c)
		tri(c, 0.12, 0.14, 0.34, 0.4, "BL")
		tri(c, 0.54, 0.1, 0.34, 0.3, "TR", true)
		tri(c, 0.5, 0.48, 0.38, 0.4, "TL")
		tri(c, 0.14, 0.6, 0.3, 0.3, "BR", true)
		rhombus(c, 0.48, 0.48, 0.07, 0.1)
	end,
	fireworks = function(c)
		for i = 0, 7 do
			local a = math.rad(i * 45)
			line(
				c,
				0.42 + math.cos(a) * 0.12,
				0.36 + math.sin(a) * 0.12,
				0.42 + math.cos(a) * 0.3,
				0.36 + math.sin(a) * 0.3,
				0.07,
				i % 2 == 1,
				true
			)
		end
		sparkle(c, 0.78, 0.72, 0.13, true)
		line(c, 0.42, 0.66, 0.42, 0.94, 0.06, false, true)
	end,
	-- Victories (a little block figure).
	figureCheer = function(c)
		figure(c, CHEER_ARMS)
	end,
	figureFlex = function(c)
		figure(c, {
			{ 0.42, 0.34, 0.22, 0.34 },
			{ 0.22, 0.34, 0.22, 0.14 },
			{ 0.58, 0.34, 0.78, 0.34 },
			{ 0.78, 0.34, 0.78, 0.14 },
		})
	end,
	figureFlip = function(c)
		-- Upside down inside a circling arrow.
		figure(holder(c, 200, 0.6, 0.5, 0.52), CHEER_ARMS)
		local x, y = arc(c, 0.5, 0.5, 0.4, 150, 385, 0.08, true)
		arrowhead(c, x, y, 475, 0.2, true)
	end,
	figureCap = function(c)
		figure(c, CHEER_ARMS, 0.08)
		rhombus(c, 0.5, 0.1, 0.24, 0.07, true) -- the mortarboard
		box(c, 0.4, 0.1, 0.2, 0.07, true)
		line(c, 0.68, 0.1, 0.72, 0.24, 0.035, true, true) -- the tassel
	end,
	figureSpin = function(c)
		-- On its back, legs up in a V, with a circling arc (Breakdance).
		figure(
			holder(c, 90, 0.72, 0.5, 0.56),
			{ { 0.42, 0.33, 0.22, 0.52 }, { 0.58, 0.33, 0.78, 0.12 } }
		)
		arc(c, 0.5, 0.52, 0.42, 200, 340, 0.06, true)
	end,
	katana = function(c)
		line(c, 0.3, 0.7, 0.86, 0.14, 0.07, false, true) -- the blade
		line(c, 0.12, 0.88, 0.3, 0.7, 0.1, true) -- the hilt
		line(c, 0.2, 0.62, 0.38, 0.8, 0.07, true, true) -- the guard
		sparkle(c, 0.84, 0.16, 0.1, true)
	end,
	butterfly = function(c)
		-- Two pairs of wings and a body.
		circle(c, 0.3, 0.36, 0.2)
		circle(c, 0.7, 0.36, 0.2)
		circle(c, 0.35, 0.68, 0.14, true)
		circle(c, 0.65, 0.68, 0.14, true)
		line(c, 0.5, 0.22, 0.5, 0.84, 0.07, false, true)
	end,
	rift = function(c)
		-- A tear in space with stars.
		rhombus(c, 0.5, 0.5, 0.17, 0.46, false)
		rhombus(c, 0.5, 0.5, 0.07, 0.32, true)
		sparkle(c, 0.2, 0.24, 0.08, true)
		sparkle(c, 0.8, 0.76, 0.1, true)
	end,
	hologram = function(c)
		figure(c, CHEER_ARMS)
		for _, y in { 0.2, 0.36, 0.52, 0.68, 0.84 } do
			local scan = box(c, 0.16, y, 0.68, 0.03, true)
			scan.BackgroundTransparency = 0.4
		end
	end,
}

-- Every icon's name.
Icons.Names = {}
for name in DRAW do
	table.insert(Icons.Names, name)
end
table.sort(Icons.Names)

function Icons.has(name: string?): boolean
	return name ~= nil and DRAW[name] ~= nil
end

-- Draws icon `name` in a `size` pixel square Frame (main `color`, white by default, and an
-- `accent`, dark by default). Unknown names draw nothing (the Frame is empty).
function Icons.draw(
	parent: Instance?,
	name: string,
	size: number,
	color: Color3?,
	accent: Color3?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Icon"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(size, size)
	local draw = DRAW[name]
	if draw then
		draw({ frame = frame, size = size, color = color or WHITE, accent = accent or INK })
	end
	frame.Parent = parent
	return frame
end

-- Recolors an icon drawn by Icons.draw (shapes with a fixed color, like coins, stay).
function Icons.paint(icon: Instance, color: Color3, accent: Color3?)
	for _, item in icon:GetDescendants() do
		local role = item:GetAttribute("IconRole")
		local wanted = if role == "main" then color elseif role == "accent" then accent else nil
		if wanted then
			if item:IsA("Frame") then
				item.BackgroundColor3 = wanted
			elseif item:IsA("UIStroke") then
				item.Color = wanted
			elseif item:IsA("TextLabel") then
				item.TextColor3 = wanted
			end
		end
	end
end

-- Makes every shape of an icon shimmer in the Iridescent holo colors (client/GradientFx).
function Icons.holo(icon: Instance)
	local CollectionService = game:GetService("CollectionService")
	for _, item in icon:GetDescendants() do
		if (item:IsA("Frame") or item:IsA("TextLabel")) and item:GetAttribute("IconRole") then
			if item:IsA("TextLabel") then
				item.TextColor3 = WHITE
			else
				(item :: Frame).BackgroundColor3 = WHITE
			end
			local gradient = item:FindFirstChildOfClass("UIGradient")
			if not gradient then
				local new = Instance.new("UIGradient")
				new.Parent = item
				gradient = new
			end
			CollectionService:AddTag(gradient :: UIGradient, "HoloGradient")
		end
	end
end

return Icons
