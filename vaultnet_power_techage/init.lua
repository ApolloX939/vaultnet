-- Techage power adapter. It connects the VaultNet network to a Techage electric network:
-- put a Techage electric cable (or any node of that network) against it and it draws from
-- the network's generators and storage, handing what it gets to the VaultNet network as
-- supply. Only the adapter is a Techage consumer; no other VaultNet part is.
--
-- Techage works in 2 second cycles. Every cycle the adapter asks vaultnet.power.request(pos)
-- how many units per second the network wants from it (at most its capacity) and tries to
-- consume ceil(units * scale) Techage units. If it gets them all it delivers those units for
-- the next few seconds, otherwise nothing (like a Technic machine, all or nothing).

local P = vaultnet.power
local CYCLE = 2
local GRACE = 4
local SCALE = tonumber(core.settings:get("vaultnet_power_techage_scale")) or 0.5
local CAP = tonumber(core.settings:get("vaultnet_power_techage_capacity")) or 60

local IDLE, ACTIVE = "vaultnet_power_techage:adapter", "vaultnet_power_techage:adapter_active"
local pre = "vaultnet_power_adapter_ta"

local function cable() return techage.ElectricCable end

local function delivered(pos)
	local meta = core.get_meta(pos)
	if meta:get_int("vn_supply_until") < core.get_gametime() then return 0 end
	return meta:get_int("vn_supply")
end

local function register(name, active)
	local side = "vaultnet_power_adapter_side.png"
	core.register_node(name, {
		description = "VaultNet Power Adapter (Techage)" .. (active and " (active)" or ""),
		paramtype2 = "4dir",
		tiles = {pre .. "_top.png", side, side, side, side,
			active and {
				name = pre .. "_front_active.png",
				animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.6},
			} or (pre .. "_front.png")},
		inventory_image = pre .. "_icon.png",
		wield_image = pre .. "_icon.png",
		groups = vaultnet.groups({vaultnet_device = 1, not_in_creative_inventory = active and 1 or nil}),
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		light_source = active and 4 or nil,
		drop = IDLE,
		vaultnet = {
			role = "power",
			power_adapter = {capacity = CAP},
			power_supply = delivered,
		},
		after_place_node = function(pos) cable():after_place_node(pos) end,
		after_dig_node = function(pos) cable():after_dig_node(pos) end,
	})
end

register(IDLE, false)
register(ACTIVE, true)

-- A Techage consumer on the electric network ("ele1"), on every side.
networks.power.register_nodes({IDLE, ACTIVE}, cable(), "con")

core.register_abm({
	label = "VaultNet techage power adapter",
	nodenames = {IDLE, ACTIVE},
	interval = CYCLE,
	chance = 1,
	action = function(pos, node)
		local meta = core.get_meta(pos)
		local units = vaultnet.require_power and P.request(pos) or 0
		if units > 0 then
			local need = math.ceil(units * SCALE)
			if networks.power.consume_power(pos, cable(), nil, need) >= need then
				meta:set_int("vn_supply", units)
				meta:set_int("vn_supply_until", core.get_gametime() + GRACE)
			end
		end
		local got = delivered(pos)
		local want = got > 0 and ACTIVE or IDLE
		if node.name ~= want then
			node.name = want
			core.swap_node(pos, node)
		end
		local text = ("VaultNet Power Adapter (Techage)\nDelivering %d of %d units/s"):format(got, units)
		if meta:get_string("infotext") ~= text then meta:set_string("infotext", text) end
	end,
})

if core.get_modpath("default") then
	local S = "default:steel_ingot"
	local V = function(n) return "vaultnet_components:" .. n end
	core.register_craft({
		output = IDLE,
		recipe = {
			{S, "techage:electric_cableS", S},
			{V"coil", V"coupler", V"coil"},
			{S, V"circuit", S},
		},
	})
end
