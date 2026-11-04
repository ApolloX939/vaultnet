-- Minetest Game recipes.

local S, C = "default:steel_ingot", "default:copper_ingot"

core.register_craft({
	output = "vaultnet_wireless:relay",
	recipe = {
		{"default:diamond", "default:mese_crystal", "default:diamond"},
		{S, C, S},
		{S, S, S},
	},
})
