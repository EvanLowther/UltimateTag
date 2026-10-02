-- Compiles every Luau file under src/ to catch syntax errors without opening Studio.
--   lune run tools/check-syntax.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local bad = 0
local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.luau$") then
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				bad += 1
				print("SYNTAX " .. path .. ": " .. tostring(err))
			end
		end
	end
end
walk("src")
print(if bad == 0 then "Syntax OK" else bad .. " file(s) with syntax errors")
process.exit(if bad == 0 then 0 else 1)
