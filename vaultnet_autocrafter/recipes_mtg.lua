-- Minetest Game recipes.

local S, G, C = "default:steel_ingot", "default:glass", "default:copper_ingot"

core.register_craft({
	output = "vaultnet_autocrafter:autocrafter",
	recipe = {
		{S, G, S},
		{C, "default:mese_crystal", C},
		{S, "default:chest", S},
	},
})
