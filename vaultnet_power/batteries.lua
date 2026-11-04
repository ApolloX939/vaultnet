-- Batteries: buffer power on the network. While the other sources cover less than the
-- parts draw, batteries make up the difference from their charge (up to their rate);
-- while there is a surplus, they charge (and adapters are asked for extra to keep them
-- topped up). See budget.lua. Capacity is in unit-seconds, rate in units per second.
-- A battery keeps its charge when dug and placed again.

local P = vaultnet.power

local TIERS = {
	{id = "small", name = "Small", capacity = 600, rate = 20},
	{id = "medium", name = "Medium", capacity = 3000, rate = 60},
	{id = "large", name = "Large", capacity = 15000, rate = 200},
}
local LEVELS = 5 -- front looks 0 (empty) .. 4 (full)
P.battery_tiers = TIERS

local function node_name(t, level) return ("vaultnet_power:battery_%s_%d"):format(t.id, level) end

local by_name = {} -- node name -> {tier, level}
local names = {}

local function level_of(charge, cap)
	if charge <= 0 then return 0 end
	return math.min(LEVELS - 1, math.max(1, math.ceil(charge / cap * (LEVELS - 1))))
end

local function describe(t, charge)
	return ("%s VaultNet Battery\nCharge: %d / %d\nRate: %d units/s"):format(t.name, charge, t.capacity, t.rate)
end

for _, t in ipairs(TIERS) do
	for level = 0, LEVELS - 1 do
		local name = node_name(t, level)
		local side = ("vaultnet_power_battery_%s_side.png"):format(t.id)
		core.register_node(name, {
			description = t.name .. " VaultNet Battery" .. (level > 0 and (" (%d)"):format(level) or ""),
			paramtype2 = "4dir",
			tiles = {("vaultnet_power_battery_%s_top.png"):format(t.id), side, side, side, side,
				("vaultnet_power_battery_%s_front%d.png"):format(t.id, level)},
			inventory_image = ("vaultnet_power_battery_%s_icon.png"):format(t.id),
			wield_image = ("vaultnet_power_battery_%s_icon.png"):format(t.id),
			groups = {cracky = 2, vaultnet_device = 1, not_in_creative_inventory = level > 0 and 1 or nil},
			sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
			drop = node_name(t, 0),
			vaultnet = {
				role = "battery",
				power_battery = {capacity = t.capacity, rate = t.rate},
			},
			-- a placed battery starts with the charge its item carried
			after_place_node = function(pos, _, itemstack)
				local charge = tonumber(itemstack and itemstack:get_meta():get_string("charge")) or 0
				core.get_meta(pos):set_float("charge", math.min(charge, t.capacity))
			end,
			preserve_metadata = function(pos, oldnode, oldmeta, drops)
				local charge = tonumber(oldmeta and oldmeta.charge) or 0
				if charge > 0 and drops[1] then
					local meta = drops[1]:get_meta()
					meta:set_string("charge", tostring(charge))
					meta:set_string("description", describe(t, charge))
					-- a charged battery is worth more than an empty one: keep EMC mods from
					-- converting (and so destroying) the charge
					meta:set_string("no_emc", "true")
				end
			end,
		})
		by_name[name] = {tier = t, level = level}
		names[#names + 1] = name
	end
end

-- Keep the look and infotext in step with the charge.
core.register_abm({
	label = "VaultNet battery display",
	nodenames = names,
	interval = 2,
	chance = 1,
	action = function(pos, node)
		local info = by_name[node.name]
		local t = info.tier
		local meta = core.get_meta(pos)
		local charge = meta:get_float("charge")
		local want = node_name(t, level_of(charge, t.capacity))
		if want ~= node.name then
			node.name = want
			core.swap_node(pos, node)
		end
		local text = describe(t, math.floor(charge))
		if meta:get_string("infotext") ~= text then meta:set_string("infotext", text) end
	end,
})

if core.get_modpath("default") then
	local S, C, D = "default:steel_ingot", "default:copper_ingot", "default:diamond"
	local V = function(n) return "vaultnet_components:" .. n end
	core.register_craft({
		output = node_name(TIERS[1], 0),
		recipe = {{S, V"capacitor", S}, {C, V"capacitor", C}, {S, S, S}},
	})
	core.register_craft({
		output = node_name(TIERS[2], 0),
		recipe = {{V"capacitor", V"circuit", V"capacitor"}, {V"casing", V"capacitor", V"casing"}, {S, S, S}},
	})
	core.register_craft({
		output = node_name(TIERS[3], 0),
		recipe = {{V"capacitor", V"processor", V"capacitor"}, {V"capacitor", V"casing", V"capacitor"}, {V"casing", D, V"casing"}},
	})
end
