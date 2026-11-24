-- Drive items. A drive is any item whose definition has:
--   vaultnet_drive = { capacity = <total items> }
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

-- The item's tooltip: its name, then how full it is. A def may set `short_description`
-- to the plain name; otherwise the first line of its description is used.
function D.describe(idef, name, used, capacity)
	local base = idef and (idef.short_description or (idef.description or ""):match("^[^\n]*")) or ""
	if base == "" then base = name end
	return base .. "\n" .. vaultnet.format_usage(used, capacity, "items")
end

function D.state_of(def, data)
	local fullness = def.capacity > 0 and data.used / def.capacity or 1
	return math.min(D.STATES, math.max(1, math.ceil(fullness * D.STATES)))
end

-- data = {items = {[key] = count}, used = n, types = n}
--
-- Item meta can not hold arbitrary strings: the engine strips the control
-- characters \1 \2 \3 (the ItemStack string delimiters) from meta values. Item keys
-- are full ItemStack strings, which contain exactly those whenever an item has
-- metadata, so keys are stored base64-encoded (format v = 2). Drives written
-- before that (no `v`) hold raw keys and are read as-is.
--
-- Decoding (deserialize + base64 of every key) is the expensive part of every drive
-- operation, and the same unchanged drives are read by every device on every tick. So
-- decoded contents are kept in a small cache keyed by the serialized meta string: an
-- unchanged drive is decoded once, and save() adds the new state. A cached table is
-- shared, so readers use peek() and must not modify it; load() hands out a private copy.
local DECODE_CACHE_MAX = 64
local decode_cache, decode_cache_size = {}, 0
local EMPTY = {items = {}, used = 0, types = 0}

local function cache_put(s, data)
	if decode_cache[s] == nil then
		if decode_cache_size >= DECODE_CACHE_MAX then
			decode_cache, decode_cache_size = {}, 0
		end
		decode_cache_size = decode_cache_size + 1
	end
	decode_cache[s] = data
end

local function decode(s)
	local hit = decode_cache[s]
	if hit then return hit end
	local raw = core.deserialize(s)
	local data
	if type(raw) ~= "table" or type(raw.items) ~= "table" then
		data = EMPTY
	elseif raw.v ~= 2 then
		data = raw
	else
		local items = {}
		for k, n in pairs(raw.items) do items[core.decode_base64(k)] = n end
		data = {items = items, used = raw.used, types = raw.types}
	end
	cache_put(s, data)
	return data
end

-- read-only view of the contents (shared with the cache: do not modify)
local function peek(stack)
	local s = stack:get_meta():get_string(KEY)
	if s == "" then return EMPTY end
	return decode(s)
end

-- private copy that the caller may modify (then save())
local function load(stack)
	local shared = peek(stack)
	local items = {}
	for k, n in pairs(shared.items) do items[k] = n end
	return {items = items, used = shared.used, types = shared.types}
end

local function save(stack, data)
	local def, idef = drive_def(stack)
	local meta = stack:get_meta()
	local items = {}
	for k, n in pairs(data.items) do items[core.encode_base64(k)] = n end
	local serialized = core.serialize({v = 2, items = items, used = data.used, types = data.types})
	meta:set_string(KEY, serialized)
	cache_put(serialized, data) -- the caller is done with `data`, so the cache may keep it
	meta:set_string("description", D.describe(idef, stack:get_name(), data.used, def.capacity))
	-- Mods that turn items into another currency (EMC) look at this flag: a drive with
	-- contents is worth more than the empty drive and would be destroyed by a conversion.
	meta:set_string("no_emc", data.used > 0 and "true" or "")
	-- Optional per-state look: def.state_image(state) -> texture string.
	if def.state_image then
		local state = D.state_of(def, data)
		local img = def.state_image(state)
		meta:set_string("inventory_image", img)
		meta:set_string("wield_image", img)
	end
end

-- Make the no_emc flag match the contents (drives written before the flag existed).
-- Mutates the stack; returns true when it changed.
function D.sync_flags(stack)
	local def = drive_def(stack)
	if not def then return false end
	local want = peek(stack).used > 0 and "true" or ""
	local meta = stack:get_meta()
	if meta:get_string("no_emc") == want then return false end
	meta:set_string("no_emc", want)
	return true
end

function D.info(stack)
	local def = drive_def(stack)
	if not def then return nil end
	local data = peek(stack)
	return {
		used = data.used,
		capacity = def.capacity,
		types = data.types,
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
		for k, v in pairs(peek(stack).items) do out[k] = v end
	end
	return out
end

function D.count(stack, key)
	if not drive_def(stack) then return 0 end
	return peek(stack).items[key] or 0
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
