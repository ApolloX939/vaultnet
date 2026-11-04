-- Minetest Game recipes.

local S, G, C = "default:steel_ingot", "default:glass", "default:copper_ingot"

core.register_craft({
	output = "vaultnet_power:generator",
	recipe = {
		{S, S, S},
		{C, "default:furnace", C},
		{S, "default:mese_crystal_fragment", S},
	},
})

core.register_craft({
	output = "vaultnet_power:solar",
	recipe = {
		{G, G, G},
		{C, "default:mese_crystal", C},
		{S, S, S},
	},
})
