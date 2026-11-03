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

-- Unique, metadata-preserving key for an item "kind": the full ItemStack
-- string (name, wear, all meta) with the count normalised to 1.
function vaultnet.item_key(stack)
	local s = ItemStack(stack)
	s:set_count(1)
	return s:to_string()
end

-- Rebuild a stack from a key. Returns an empty stack when count <= 0.
function vaultnet.key_to_stack(key, count)
	local s = ItemStack(key)
	s:set_count(count)
	return s
end
