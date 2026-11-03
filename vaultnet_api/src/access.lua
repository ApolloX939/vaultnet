-- Per-core access lists. Data lives in the core node's meta:
--   owner            string
--   vaultnet_access  serialized { [player] = {put=bool, pull=bool, admin=bool} }
-- `admin` implies put and pull and allows editing other players' access.
-- The owner and players with the `vaultnet_admin` privilege always have all.

core.register_privilege("vaultnet_admin", {
	description = "Full access to every VaultNet core",
	give_to_singleplayer = false,
})

local A = {}
vaultnet.access = A

A.PERMS = {"put", "pull", "admin"}
local valid = {put = true, pull = true, admin = true}

local function load(pos)
	local s = core.get_meta(pos):get_string("vaultnet_access")
	if s == "" then return {} end
	return core.deserialize(s) or {}
end

local function save(pos, data)
	core.get_meta(pos):set_string("vaultnet_access", core.serialize(data))
end

function A.init(pos, owner)
	local meta = core.get_meta(pos)
	meta:set_string("owner", owner or "")
	if meta:get_string("vaultnet_access") == "" then save(pos, {}) end
end

function A.get_owner(pos)
	return core.get_meta(pos):get_string("owner")
end

function A.can(pos, name, perm)
	if not valid[perm] then return false end
	if not name or name == "" then return false end
	if name == A.get_owner(pos) then return true end
	if core.check_player_privs(name, {vaultnet_admin = true}) then return true end
	local p = load(pos)[name]
	if not p then return false end
	if p.admin then return true end
	return p[perm] == true
end

-- Set a player's access. `perms` = {put=?, pull=?, admin=?}. All false removes
-- the player. Returns true or (false, reason).
function A.set(pos, setter, target, perms)
	if not A.can(pos, setter, "admin") then return false, "not_admin" end
	if type(target) ~= "string" or target == "" then return false, "bad_name" end
	if target == A.get_owner(pos) then return false, "is_owner" end
	local entry = {}
	for _, k in ipairs(A.PERMS) do entry[k] = perms[k] == true end
	local data = load(pos)
	if entry.put or entry.pull or entry.admin then
		data[target] = entry
	else
		data[target] = nil
	end
	save(pos, data)
	return true
end

function A.remove(pos, setter, target)
	return A.set(pos, setter, target, {})
end

-- Sorted array of {name, put, pull, admin}, owner excluded.
function A.list(pos)
	local out = {}
	for name, p in pairs(load(pos)) do
		out[#out + 1] = {name = name, put = p.put, pull = p.pull, admin = p.admin}
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end
