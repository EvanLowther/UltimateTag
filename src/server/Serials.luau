--!strict
-- Serial numbers for Iridescent items: the 7th Phantom ever unboxed is "No. 7". One global
-- counter per item in a DataStore ("Serials_v1"); without data stores (Studio with API access
-- off) a counter for this server's session. The number is kept in the owner's profile
-- (Serials[item id]) and shown on their title and in the Locker.
local DataStoreService = game:GetService("DataStoreService")

local Serials = {}

local storesOn = true
local counters: DataStore? = nil
local session: { [string]: number } = {}

local function store(): DataStore?
	if storesOn and not counters then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("Serials_v1")
		end)
		if ok then
			counters = result
		else
			storesOn = false
		end
	end
	return if storesOn then counters else nil
end

-- Takes the next serial number for `itemId` (yields while it's saved).
function Serials.next(itemId: string): number
	local s = store()
	if s then
		local number: number? = nil
		local ok, err = pcall(function()
			number = s:UpdateAsync(itemId, function(old: number?)
				return (old or 0) + 1
			end)
		end)
		if ok and number then
			return number
		end
		local text = tostring(err)
		if string.find(text, "API", 1, true) or string.find(text, "publish", 1, true) then
			storesOn = false -- data stores aren't available here: count for this session
		end
	end
	session[itemId] = (session[itemId] or 0) + 1
	return session[itemId]
end

return Serials
