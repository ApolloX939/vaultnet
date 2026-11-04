-- Minetest Game + Technic recipes.

local S = "default:steel_ingot"
local V = function(n) return "vaultnet_components:" .. n end

core.register_craft({
	output = "vaultnet_power_technic:adapter_lv",
	recipe = {
		{S, "technic:lv_cable", S},
		{V"coil", V"coupler", V"coil"},
		{S, V"circuit", S},
	},
})

core.register_craft({
	output = "vaultnet_power_technic:adapter_mv",
	recipe = {
		{S, "technic:mv_cable", S},
		{V"coil", V"coupler", V"coil"},
		{S, V"processor", S},
	},
})

core.register_craft({
	output = "vaultnet_power_technic:adapter_hv",
	recipe = {
		{S, "technic:hv_cable", S},
		{V"coil", V"coupler", V"coil"},
		{V"casing", V"processor", V"casing"},
	},
})
