local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

local R = 2 / 16 -- cable half-thickness (thin)

local function box()
	return {
		type = "connected",
		fixed = {-R, -R, -R, R, R, R},
		connect_top = {-R, R, -R, R, 0.5, R},
		connect_bottom = {-R, -0.5, -R, R, -R, R},
		connect_front = {-R, -R, -0.5, R, R, -R},
		connect_back = {-R, -R, R, R, R, 0.5},
		connect_left = {-0.5, -R, -R, -R, R, R},
		connect_right = {R, -R, -R, 0.5, R, R},
	}
end

local function animated(texture)
	return {
		name = texture,
		animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.6},
	}
end

-- Shared node definition. `extra` overrides/extends it.
local function register(name, texture, is_animated, vn, extra)
	local def = {
		drawtype = "nodebox",
		paramtype = "light",
		node_box = box(),
		selection_box = box(),
		collision_box = box(),
		connects_to = {"group:vaultnet_device"},
		tiles = {is_animated and animated(texture) or texture},
		use_texture_alpha = "clip",
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		groups = {cracky = 2, oddly_breakable_by_hand = 1, vaultnet_device = 1},
		vaultnet = vn,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_node(name, def)
end

-- Plain cable and its animated active twin -----------------------------------

register("vaultnet_cables:cable", "vaultnet_cables_cable.png", false, {
	role = "cable",
	active_variant = "vaultnet_cables:cable_active",
}, {
	description = "VaultNet Cable",
})

register("vaultnet_cables:cable_active", "vaultnet_cables_cable_active.png", true, {
	role = "cable",
	inactive_variant = "vaultnet_cables:cable",
}, {
	description = "VaultNet Cable (active)",
	drop = "vaultnet_cables:cable",
	light_source = 3,
	groups = {cracky = 2, oddly_breakable_by_hand = 1, vaultnet_device = 1,
		not_in_creative_inventory = 1},
})

-- Toggle cable (only with require_power) --------------------------------------

if vaultnet.require_power then
	local ON, ON_ACTIVE, OFF =
		"vaultnet_cables:toggle_on", "vaultnet_cables:toggle_on_active", "vaultnet_cables:toggle_off"

	local function toggle(pos, node, player)
		local pname = player and player:get_player_name() or ""
		if core.is_protected(pos, pname) then
			core.record_protection_violation(pos, pname)
			return
		end
		local turning_off = node.name ~= OFF
		node.name = turning_off and OFF or ON
		core.swap_node(pos, node)
		-- conducts() changed: networks on both sides must be rebuilt
		vaultnet.notify_changed(pos)
		core.sound_play("default_dig_metal", {pos = pos, gain = 0.3}, true)
	end

	local not_creative = {cracky = 2, oddly_breakable_by_hand = 1,
		vaultnet_device = 1, not_in_creative_inventory = 1}

	register(ON, "vaultnet_cables_toggle_on.png", false, {
		role = "cable",
		active_variant = ON_ACTIVE,
	}, {
		description = "VaultNet Toggle Cable",
		on_rightclick = toggle,
	})

	register(ON_ACTIVE, "vaultnet_cables_toggle_on_active.png", true, {
		role = "cable",
		inactive_variant = ON,
	}, {
		description = "VaultNet Toggle Cable (active)",
		drop = ON,
		light_source = 3,
		groups = not_creative,
		on_rightclick = toggle,
	})

	-- Off: isolates itself, which splits any network running through it.
	register(OFF, "vaultnet_cables_toggle_off.png", false, {
		role = "cable",
		conducts = function() return false end,
	}, {
		description = "VaultNet Toggle Cable (off)",
		drop = ON,
		groups = not_creative,
		on_rightclick = toggle,
	})
end

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
