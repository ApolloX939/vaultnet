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
