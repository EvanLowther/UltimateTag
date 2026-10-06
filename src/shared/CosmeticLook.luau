--!strict
-- How cosmetics are colored, shared by everything that draws them (speed trails, titles over
-- heads, the menus): color sequences for each trail pattern and title style (shared/Catalog
-- looks), and the flowing holo colors of Iridescent items.
local CosmeticLook = {}

local WHITE = Color3.new(1, 1, 1)
local EDGE = 0.002 -- how sharp a hard color edge is (keypoints this far apart)

-- The holo palette Iridescent items cycle through: pink, light pink, lilac, sky, mint, butter.
CosmeticLook.Holo = {
	Color3.fromRGB(255, 80, 120),
	Color3.fromRGB(255, 154, 213),
	Color3.fromRGB(180, 140, 255),
	Color3.fromRGB(124, 232, 255),
	Color3.fromRGB(157, 255, 207),
	Color3.fromRGB(255, 224, 138),
}

-- The holo color at `position` round the palette (0-1, wraps).
function CosmeticLook.holoColor(position: number): Color3
	local colors = CosmeticLook.Holo
	local scaled = (position % 1) * #colors
	local index = math.floor(scaled)
	local a = colors[index + 1]
	local b = colors[(index + 1) % #colors + 1]
	return a:Lerp(b, scaled - index)
end

-- The holo palette as a gradient, moved along by `phase` (0-1) so it flows when animated.
function CosmeticLook.holoSequence(phase: number): ColorSequence
	local points = {}
	local count = 7
	for i = 0, count - 1 do
		local t = i / (count - 1)
		table.insert(points, ColorSequenceKeypoint.new(t, CosmeticLook.holoColor(t * 0.85 + phase)))
	end
	return ColorSequence.new(points)
end

-- One color, or an even smooth gradient through several.
function CosmeticLook.sequence(colors: { Color3 }): ColorSequence
	if #colors <= 1 then
		return ColorSequence.new(colors[1] or WHITE)
	end
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

-- Hard-edged bands: band i is colors[i] (cycling), `widths` long (they should add up to 1).
-- At most 10 bands (a sequence holds 20 keypoints).
function CosmeticLook.bands(colors: { Color3 }, widths: { number }): ColorSequence
	local points = {}
	local start = 0
	for i, width in widths do
		local color = colors[(i - 1) % #colors + 1]
		local last = i == #widths
		local finish = if last then 1 else math.min(start + width, 1 - EDGE)
		table.insert(points, ColorSequenceKeypoint.new(start, color))
		table.insert(points, ColorSequenceKeypoint.new(if last then 1 else finish - EDGE, color))
		start = finish
	end
	return ColorSequence.new(points)
end

-- `count` even stripes, a and b in turn.
function CosmeticLook.stripes(a: Color3, b: Color3, count: number): ColorSequence
	local widths = {}
	for i = 1, count do
		widths[i] = 1 / count
	end
	return CosmeticLook.bands({ a, b }, widths)
end

-- Uneven blotches of up to four colors, in a fixed scrambled order.
local CAMO_WIDTHS = { 0.12, 0.07, 0.14, 0.09, 0.06, 0.13, 0.08, 0.11, 0.1, 0.1 }
local CAMO_ORDER = { 1, 3, 2, 4, 1, 2, 4, 3, 2, 1 }
function CosmeticLook.camo(colors: { Color3 }): ColorSequence
	local ordered = {}
	for i, index in CAMO_ORDER do
		ordered[i] = colors[(index - 1) % #colors + 1]
	end
	return CosmeticLook.bands(ordered, CAMO_WIDTHS)
end

-- The color sequences a trail look is drawn with along its length: one lane, or two side by
-- side (Split, Checker). nil for Holo, whose colors move (holoSequence each frame).
function CosmeticLook.trailLanes(look: { [string]: any }): { ColorSequence }?
	local colors = (look.Colors or { WHITE }) :: { Color3 }
	local a, b = colors[1], colors[2] or colors[1]
	local pattern = look.Pattern
	if pattern == "Holo" then
		return nil
	elseif pattern == "Stripes" then
		return { CosmeticLook.stripes(a, b, 8) }
	elseif pattern == "Split" then
		return { ColorSequence.new(a), ColorSequence.new(b) }
	elseif pattern == "Checker" then
		return { CosmeticLook.stripes(a, b, 8), CosmeticLook.stripes(b, a, 8) }
	elseif pattern == "Camo" then
		return { CosmeticLook.camo(colors) }
	end
	return { CosmeticLook.sequence(colors) } -- Solid, Gradient
end

-- A gradient with a white shine band in the middle; sliding its offset sweeps the shine across.
function CosmeticLook.shineSequence(colors: { Color3 }): ColorSequence
	local a = colors[1] or WHITE
	local b = colors[2] or a
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.38, b),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(0.62, b),
		ColorSequenceKeypoint.new(1, a),
	})
end

-- How a title's text is colored: a gradient (nil for one solid color), its rotation in
-- degrees, and its animation tag ("HoloGradient" or "ShineGradient", see client/GradientFx).
function CosmeticLook.titleGradient(look: { [string]: any }): (ColorSequence?, number, string?)
	local colors = (look.Colors or { WHITE }) :: { Color3 }
	local style = look.Style
	if style == "TwoTone" then
		return CosmeticLook.bands({ colors[1], colors[2] or colors[1] }, { 0.52, 0.48 }), 90, nil
	elseif style == "Gradient" then
		return CosmeticLook.sequence(colors), 0, nil
	elseif style == "Shine" then
		return CosmeticLook.shineSequence(colors), 0, "ShineGradient"
	elseif style == "Holo" then
		return CosmeticLook.holoSequence(0), 0, "HoloGradient"
	end
	return nil, 0, nil
end

-- The main color of a look (a solid title's color, the first color of anything else).
function CosmeticLook.mainColor(look: { [string]: any }): Color3
	local colors = look.Colors :: { Color3 }?
	if colors and colors[1] then
		return colors[1]
	end
	return CosmeticLook.Holo[1]
end

return CosmeticLook
