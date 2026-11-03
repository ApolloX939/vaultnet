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
