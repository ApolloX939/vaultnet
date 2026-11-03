-- Device registry. A node is a VaultNet device when its definition has a
-- `vaultnet` table (see README.md for the fields).

function vaultnet.get_def(name)
	local def = core.registered_nodes[name]
	return def and def.vaultnet or nil
end

-- Returns (vaultnet def, node) for the node at pos, or nil when it is not a
-- device or the area is not loaded.
function vaultnet.get_device(pos)
	local node = core.get_node_or_nil(pos)
	if not node then return nil end
	local def = vaultnet.get_def(node.name)
	if not def then return nil end
	return def, node
end

-- After all mods are loaded: tag devices with the vaultnet_device group and
-- wrap on_construct/on_destruct so the network cache is invalidated
-- automatically (also covers WorldEdit, explosions, etc.).
core.register_on_mods_loaded(function()
	local names = {}
	for name, def in pairs(core.registered_nodes) do
		if def.vaultnet then names[#names + 1] = name end
	end

	for _, name in ipairs(names) do
		local def = core.registered_nodes[name]
		if not def.vaultnet.role then
			core.log("warning", "[vaultnet_api] " .. name ..
				" has no vaultnet.role, using \"device\"")
			def.vaultnet.role = "device"
		end

		local groups = {}
		for k, v in pairs(def.groups or {}) do groups[k] = v end
		groups.vaultnet_device = 1

		local on_construct, on_destruct = def.on_construct, def.on_destruct
		core.override_item(name, {
			groups = groups,
			on_construct = function(pos)
				if on_construct then on_construct(pos) end
				vaultnet.notify_changed(pos)
			end,
			on_destruct = function(pos)
				if on_destruct then on_destruct(pos) end
				vaultnet.notify_changed(pos)
			end,
		})
	end
end)
