-- Drive items. A drive is any item whose definition has:
--   vaultnet_drive = { capacity = <total items>, max_types = <distinct kinds, optional> }
-- Contents live in the drive ItemStack's own meta, so a drive keeps its items
-- when carried. Stored items are keyed by their full ItemStack string (name,
-- wear and every meta field), so they come back out byte-for-byte identical.

local D = {}
vaultnet.drive = D

local KEY = "vaultnet_contents"

D.STATES = 5
-- green -> red, indexed by D.state()
D.STATE_COLORS = {"#00c800", "#7fc800", "#c8c800", "#c87f00", "#c80000"}

local function drive_def(stack)
	local idef = core.registered_items[stack:get_name()]
	return idef and idef.vaultnet_drive or nil, idef
end

function D.is_drive(stack)
	return drive_def(stack) ~= nil
end

-- data = {items = {[key] = count}, used = n, types = n}
local function load(stack)
	local s = stack:get_meta():get_string(KEY)
	local data = s ~= "" and core.deserialize(s) or nil
	if type(data) ~= "table" or type(data.items) ~= "table" then
		data = {items = {}, used = 0, types = 0}
	end
	return data
end

local function save(stack, data)
	local def, idef = drive_def(stack)
	local meta = stack:get_meta()
	meta:set_string(KEY, core.serialize(data))
	meta:set_string("description", (idef.description or stack:get_name()) ..
		"\n" .. data.used .. " / " .. def.capacity .. " items")
end

function D.info(stack)
	local def = drive_def(stack)
	if not def then return nil end
	local data = load(stack)
	return {
		used = data.used,
		capacity = def.capacity,
		types = data.types,
		max_types = def.max_types,
		fullness = def.capacity > 0 and data.used / def.capacity or 1,
	}
end

-- 1 (empty/low, green) .. D.STATES (full, red)
function D.state(stack)
	local info = D.info(stack)
	if not info then return 1 end
	return math.min(D.STATES, math.max(1, math.ceil(info.fullness * D.STATES)))
end

-- Copy of {[key] = count}
function D.contents(stack)
	local out = {}
	if drive_def(stack) then
		for k, v in pairs(load(stack).items) do out[k] = v end
	end
	return out
end

function D.count(stack, key)
	if not drive_def(stack) then return 0 end
	return load(stack).items[key] or 0
end

-- Store as much of `itemstack` as fits. Mutates the drive stack (call
-- slot.set afterwards) and returns the number of items accepted. Drives can
-- not be stored in drives.
function D.add(stack, itemstack)
	local def = drive_def(stack)
	if not def or itemstack:is_empty() or D.is_drive(itemstack) then return 0 end
	local data = load(stack)
	local free = def.capacity - data.used
	if free <= 0 then return 0 end
	local key = vaultnet.item_key(itemstack)
	local existing = data.items[key]
	if not existing and def.max_types and data.types >= def.max_types then
		return 0
	end
	local n = math.min(free, itemstack:get_count())
	if not existing then data.types = data.types + 1 end
	data.items[key] = (existing or 0) + n
	data.used = data.used + n
	save(stack, data)
	return n
end

-- Remove up to `count` of `key`. Mutates the drive stack; returns the number
-- actually removed.
function D.take(stack, key, count)
	if not drive_def(stack) then return 0 end
	local data = load(stack)
	local have = data.items[key]
	if not have or count <= 0 then return 0 end
	local n = math.min(have, count)
	if n == have then
		data.items[key] = nil
		data.types = data.types - 1
	else
		data.items[key] = have - n
	end
	data.used = data.used - n
	save(stack, data)
	return n
end
