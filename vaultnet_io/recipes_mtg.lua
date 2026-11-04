-- Minetest Game recipes.

local S, G, C = "default:steel_ingot", "default:glass", "default:copper_ingot"

core.register_craft({
	output = "vaultnet_io:terminal",
	recipe = {
		{S, S, S},
		{G, "default:mese_crystal_fragment", G},
		{S, C, S},
	},
})

core.register_craft({
	output = "vaultnet_io:inserter",
	recipe = {
		{S, "default:mese_crystal_fragment", S},
		{C, "default:chest", C},
		{S, S, S},
	},
})

core.register_craft({
	output = "vaultnet_io:exporter",
	recipe = {
		{S, S, S},
		{C, "default:chest", C},
		{S, "default:mese_crystal_fragment", S},
	},
})

-- Logistica-style devices are upgrades of the basic ones.
core.register_craft({
	type = "shapeless",
	output = "vaultnet_io:requester",
	recipe = {"vaultnet_io:exporter", "default:mese_crystal_fragment", "default:paper"},
})

core.register_craft({
	type = "shapeless",
	output = "vaultnet_io:supplier",
	recipe = {"vaultnet_io:inserter", "default:mese_crystal_fragment", "default:paper"},
})
