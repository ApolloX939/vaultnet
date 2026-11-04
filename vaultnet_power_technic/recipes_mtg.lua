-- Minetest Game + Technic recipes.

local S, C = "default:steel_ingot", "default:copper_ingot"

core.register_craft({
	output = "vaultnet_power_technic:adapter_lv",
	recipe = {
		{S, "technic:lv_cable", S},
		{C, "technic:machine_casing", C},
		{S, "default:mese_crystal_fragment", S},
	},
})

core.register_craft({
	output = "vaultnet_power_technic:adapter_mv",
	recipe = {
		{S, "technic:mv_cable", S},
		{C, "technic:machine_casing", C},
		{S, "default:mese_crystal", S},
	},
})

core.register_craft({
	output = "vaultnet_power_technic:adapter_hv",
	recipe = {
		{S, "technic:hv_cable", S},
		{C, "technic:machine_casing", C},
		{S, "default:diamond", S},
	},
})
