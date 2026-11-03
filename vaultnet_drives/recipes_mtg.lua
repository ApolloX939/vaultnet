-- Minetest Game recipes. Tiers are crafted from raw materials (never from a
-- lower drive) so no stored contents can be lost in a craft.

local S, G, C = "default:steel_ingot", "default:glass", "default:copper_ingot"

core.register_craft({
	output = "vaultnet_drives:drive1",
	recipe = {
		{S, G, S},
		{S, "default:mese_crystal_fragment", S},
		{S, C, S},
	},
})

core.register_craft({
	output = "vaultnet_drives:drive2",
	recipe = {
		{S, G, S},
		{S, "default:mese_crystal", S},
		{S, C, S},
	},
})

core.register_craft({
	output = "vaultnet_drives:drive3",
	recipe = {
		{"default:mese_crystal", G, "default:mese_crystal"},
		{S, "default:diamond", S},
		{S, C, S},
	},
})

core.register_craft({
	output = "vaultnet_drives:drive4",
	recipe = {
		{"default:diamond", G, "default:diamond"},
		{"default:mese_crystal", "default:mese_block", "default:mese_crystal"},
		{S, C, S},
	},
})
