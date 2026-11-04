-- Small shared helpers.

vaultnet.DIRS = {
	{x = 1, y = 0, z = 0},
	{x = -1, y = 0, z = 0},
	{x = 0, y = 1, z = 0},
	{x = 0, y = -1, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 0, y = 0, z = -1},
}

function vaultnet.copy_pos(p)
	return {x = p.x, y = p.y, z = p.z}
end

function vaultnet.pos_hash(p)
	return core.hash_node_position({
		x = math.floor(p.x + 0.5),
		y = math.floor(p.y + 0.5),
		z = math.floor(p.z + 0.5),
	})
end

-- Unique, metadata-preserving key for an item "kind" (count ignored). Items without
-- meta use their plain ItemStack string ("name 1 wear"). Items with meta use
-- "vn2:" plus a canonical serialization (name, wear, meta fields sorted by name):
-- ItemStack:to_string() lists meta fields in an order that depends on how they were
-- set, so the same item could otherwise end up as two different kinds.
function vaultnet.item_key(stack)
	local s = ItemStack(stack)
	local fields = s:get_meta():to_table().fields
	if next(fields) == nil then
		s:set_count(1)
		return s:to_string()
	end
	local list = {}
	for k, v in pairs(fields) do list[#list + 1] = {k, v} end
	table.sort(list, function(a, b) return a[1] < b[1] end)
	return "vn2:" .. core.serialize({s:get_name(), s:get_wear(), list})
end

-- Rebuild a stack from a key. Returns an empty stack when count <= 0.
function vaultnet.key_to_stack(key, count)
	local s
	if key:sub(1, 4) == "vn2:" then
		local t = core.deserialize(key:sub(5), true)
		s = ItemStack(t[1])
		s:set_wear(t[2])
		local meta = s:get_meta()
		for _, kv in ipairs(t[3]) do meta:set_string(kv[1], kv[2]) end
	else
		s = ItemStack(key)
	end
	s:set_count(count)
	return s
end

-- The item name of a key, and its maximum stack size.
function vaultnet.key_name(key)
	return vaultnet.key_to_stack(key, 1):get_name()
end

function vaultnet.key_stack_max(key)
	return vaultnet.key_to_stack(key, 1):get_stack_max()
end
