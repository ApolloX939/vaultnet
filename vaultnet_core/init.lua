-- PLACEHOLDER core: just enough to see cables switch between their inactive and
-- animated active looks. The real core (access formspec, storage hub) replaces
-- this file's contents later; the node names are kept stable on purpose.

local function animated(texture)
	return {
		name = texture,
		animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.6},
	}
end

local groups = {cracky = 2, vaultnet_device = 1}

core.register_node("vaultnet_core:core", {
	description = "VaultNet Core (placeholder)",
	tiles = {"vaultnet_core_dummy.png"},
	groups = groups,
	vaultnet = {
		role = "core",
		active_variant = "vaultnet_core:core_active",
	},
	after_place_node = function(pos, placer)
		if placer then vaultnet.access.init(pos, placer:get_player_name()) end
	end,
})

core.register_node("vaultnet_core:core_active", {
	description = "VaultNet Core (placeholder, active)",
	tiles = {animated("vaultnet_core_dummy_active.png")},
	light_source = 6,
	drop = "vaultnet_core:core",
	groups = {cracky = 2, vaultnet_device = 1, not_in_creative_inventory = 1},
	vaultnet = {
		role = "core",
		inactive_variant = "vaultnet_core:core",
	},
})

-- Placeholder visual driver: every second, each network in a loaded area is set
-- active iff it has exactly one core (and power, if required). One update per
-- network per second thanks to the stamp on the cached network object.
core.register_abm({
	label = "VaultNet placeholder active-state update",
	nodenames = {"group:vaultnet_device"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local net = vaultnet.get_network(pos)
		if not net then return end
		local now = core.get_gametime()
		if net.dummy_stamp == now then return end
		net.dummy_stamp = now
		local status = net:status()
		if net.dummy_last ~= status then
			net.dummy_last = status
			core.log("action", ("[vaultnet_core placeholder] net #%d: %d nodes, %d core(s), status=%s%s"):format(
				net.id, net.count, #net.cores, status, net.incomplete and " (incomplete)" or ""))
		end
		net:apply_active(status == "ok")
	end,
})

-- PLACEHOLDER power: with vaultnet_require_power on and no vaultnet_power mod
-- yet, nothing would ever count as powered. Treat everything as powered so the
-- toggle cable can be tested. Remove when vaultnet_power exists.
if vaultnet.require_power then
	vaultnet.register_power_handler(function() return true end)
end
