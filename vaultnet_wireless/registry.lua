-- Relay registry: relay name -> positions. The name lives in each relay's node
-- meta (that is the real data); this index only lets us find the other relays of a
-- name, including ones in unloaded areas, and know which blocks to forceload. It is
-- cached in mod storage so links can be restored at startup, and stale entries are
-- pruned when a position no longer holds a relay.

local R = {}
vaultnet.wireless = R

local storage = core.get_mod_storage()
local FORCELOAD = core.settings:get_bool("vaultnet_wireless_forceload", true)
local RANGE = tonumber(core.settings:get("vaultnet_wireless_range")) or 0

local groups = {}   -- name -> {[hash] = pos}
local name_of = {}  -- hash -> name
local forced = {}   -- hash -> true while we hold a forceload for it
local failed = {}   -- hash -> true when the forceload budget was exhausted

local function hash(pos) return vaultnet.pos_hash(pos) end

local function save()
	local data = {}
	for name, members in pairs(groups) do
		local list = {}
		for _, p in pairs(members) do list[#list + 1] = {x = p.x, y = p.y, z = p.z} end
		data[name] = list
	end
	storage:set_string("relays", core.serialize(data))
end

local function load()
	local s = storage:get_string("relays")
	local data = s ~= "" and core.deserialize(s) or {}
	for name, list in pairs(data) do
		groups[name] = {}
		for _, p in ipairs(list) do
			groups[name][hash(p)] = vaultnet.copy_pos(p)
			name_of[hash(p)] = name
		end
	end
end
load()

function R.name_at(pos) return name_of[hash(pos)] end

function R.members(name)
	local out = {}
	for _, p in pairs(groups[name] or {}) do out[#out + 1] = p end
	return out
end

-- Other relays this one links to: same name, within range.
function R.partners(pos)
	local name = name_of[hash(pos)]
	local out = {}
	if not name then return out, name end
	local me = hash(pos)
	for h, p in pairs(groups[name] or {}) do
		if h ~= me and (RANGE == 0 or vector.distance(pos, p) <= RANGE) then
			out[#out + 1] = p
		end
	end
	return out, name
end

function R.is_forceloaded(pos) return forced[hash(pos)] == true end
function R.forceload_failed(pos) return failed[hash(pos)] == true end

-- Forceload every member of a name while it has 2 or more, release otherwise.
function R.refresh(name)
	local members = R.members(name)
	local want = FORCELOAD and #members >= 2
	for _, p in ipairs(members) do
		local h = hash(p)
		if want and not forced[h] then
			if core.forceload_block(p, true) then
				forced[h], failed[h] = true, nil
			else
				failed[h] = true
			end
		elseif not want and (forced[h] or failed[h]) then
			if forced[h] then core.forceload_free_block(p, true) end
			forced[h], failed[h] = nil, nil
		end
	end
end

-- Tell every network the group touches that its topology changed.
local function notify(name)
	for _, p in ipairs(R.members(name)) do vaultnet.notify_changed(p) end
end

function R.add(name, pos)
	local h = hash(pos)
	local old = name_of[h]
	if old == name then return end
	if old then R.remove(pos) end
	groups[name] = groups[name] or {}
	groups[name][h] = vaultnet.copy_pos(pos)
	name_of[h] = name
	save()
	R.refresh(name)
	notify(name)
end

function R.remove(pos)
	local h = hash(pos)
	local name = name_of[h]
	if not name then return end
	if forced[h] then core.forceload_free_block(pos, true) end
	forced[h], failed[h] = nil, nil
	groups[name][h] = nil
	name_of[h] = nil
	if next(groups[name]) == nil then groups[name] = nil end
	save()
	if groups[name] then
		R.refresh(name)     -- a lone relay is released
		notify(name)
	end
	vaultnet.notify_changed(pos)
end


-- After startup: forceload the groups that were linked when the server stopped.
core.after(1, function()
	for name in pairs(groups) do R.refresh(name) end
end)

-- Names ---------------------------------------------------------------------------

-- "base" is public (any relay with that name links). "apollo:base" is private: only
-- apollo can set it, so nobody else can join it by typing the same text.
function R.parse(name)
	local owner, rest = name:match("^([^:]+):(.+)$")
	if owner then return owner, rest end
	return nil, name
end

-- ok, name_or_error
function R.check_name(name, setter)
	name = name:match("^%s*(.-)%s*$")
	if name == "" then return true, "" end
	if #name > 48 or not name:match("^[%w_%.%-:]+$") then
		return false, "Use letters, digits and _ . - : only (48 characters at most)."
	end
	local owner, rest = R.parse(name)
	if name:find(":", 1, true) and (not owner or rest:find(":", 1, true)) then
		return false, "A private name is player:name (one colon)."
	end
	if owner and owner ~= setter and not core.check_player_privs(setter, {vaultnet_admin = true}) then
		return false, "Only " .. owner .. " can use a name that starts with " .. owner .. ":"
	end
	return true, name
end
