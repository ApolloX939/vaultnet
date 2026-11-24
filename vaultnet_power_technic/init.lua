-- Technic power adapters (LV, MV, HV). An adapter connects the VaultNet network to a
-- Technic grid: put a Technic cable of its tier against it (any side) and it draws EU
-- for the power the network needs, handing that to the network as supply. Only the
-- adapters touch Technic cables; no other VaultNet part is a Technic machine.
--
-- Each second the adapter asks vaultnet.power.request(pos) how many units the network
-- wants from it (what the other sources cannot cover, at most its capacity) and sets its
-- Technic demand to that many units * EU per unit. The switching station then either
-- supplies the whole demand or none of it; what arrived is what the adapter delivers.

local P = vaultnet.power
local EU_PER_UNIT = tonumber(core.settings:get("vaultnet_power_technic_eu_per_unit")) or 10

local TIERS = {
	{id = "lv", tier = "LV", name = "LV", cap = tonumber(core.settings:get("vaultnet_power_technic_capacity_lv")) or 40},
	{id = "mv", tier = "MV", name = "MV", cap = tonumber(core.settings:get("vaultnet_power_technic_capacity_mv")) or 200},
	{id = "hv", tier = "HV", name = "HV", cap = tonumber(core.settings:get("vaultnet_power_technic_capacity_hv")) or 1000},
}

local function names(t)
	return "vaultnet_power_technic:adapter_" .. t.id, "vaultnet_power_technic:adapter_" .. t.id .. "_active"
end

local by_name = {}   -- node name -> tier
local all_names = {}

-- Units per second currently delivered by the adapter at pos.
local function delivered(pos, t)
	local meta = core.get_meta(pos)
	local input = meta:get_int(t.tier .. "_EU_input")
	local demand = meta:get_int(t.tier .. "_EU_demand")
	if demand <= 0 or input < demand then return 0 end
	return math.min(t.cap, math.floor(input / EU_PER_UNIT))
end

local function register(t, active)
	local idle, on = names(t)
	local name = active and on or idle
	local pre = "vaultnet_power_adapter_" .. t.id
	local side = "vaultnet_power_adapter_side.png"
	core.register_node(name, {
		description = ("VaultNet Power Adapter (%s)"):format(t.name) .. (active and " (active)" or ""),
		paramtype2 = "4dir",
		tiles = {pre .. "_top.png", side, side, side, side,
			active and {
				name = pre .. "_front_active.png",
				animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.6},
			} or (pre .. "_front.png")},
		inventory_image = pre .. "_icon.png",
		wield_image = pre .. "_icon.png",
		groups = vaultnet.groups({vaultnet_device = 1, technic_machine = 1, ["technic_" .. t.id] = 1,
			not_in_creative_inventory = active and 1 or nil}),
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		light_source = active and 4 or nil,
		drop = idle,
		vaultnet = {
			role = "power",
			power_adapter = {capacity = t.cap},
			power_supply = function(pos) return delivered(pos, t) end,
		},
		on_construct = function(pos)
			core.get_meta(pos):set_int(t.tier .. "_EU_demand", 0)
		end,
	})
	technic.register_machine(t.tier, name, technic.receiver)
	by_name[name] = t
	all_names[#all_names + 1] = name
end

for _, t in ipairs(TIERS) do
	register(t, false)
	register(t, true)
end

core.register_abm({
	label = "VaultNet technic power adapter",
	nodenames = all_names,
	interval = 1,
	chance = 1,
	action = function(pos, node)
		local t = by_name[node.name]
		local meta = core.get_meta(pos)
		local units = vaultnet.require_power and vaultnet.power.request(pos) or 0
		local demand = units * EU_PER_UNIT
		if meta:get_int(t.tier .. "_EU_demand") ~= demand then
			meta:set_int(t.tier .. "_EU_demand", demand)
		end
		local got = delivered(pos, t)
		local idle, on = names(t)
		local want = got > 0 and on or idle
		if node.name ~= want then
			node.name = want
			core.swap_node(pos, node)
		end
		local text = ("VaultNet Power Adapter (%s)\nDelivering %d of %d units/s"):format(t.name, got, units)
		if meta:get_string("infotext") ~= text then meta:set_string("infotext", text) end
	end,
})

if core.get_modpath("default") then
	dofile(core.get_modpath(core.get_current_modname()) .. "/recipes_mtg.lua")
end
