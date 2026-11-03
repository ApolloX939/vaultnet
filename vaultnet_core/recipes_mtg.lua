-- Minetest Game recipes.

local S, M, D = "default:steel_ingot", "default:mese_crystal", "default:diamond"

core.register_craft({
	output = "vaultnet_core:core",
	recipe = {
		{S, M, S},
		{M, D, M},
		{S, M, S},
	},
})
