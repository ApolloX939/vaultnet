-- Minetest Game recipes for the machines themselves.

local S, C, G = "default:steel_ingot", "default:copper_ingot", "default:glass"

core.register_craft({
	output = "vaultnet_machines:smelter",
	recipe = {{S, S, S}, {C, "default:furnace", C}, {S, "default:mese_crystal_fragment", S}},
})
core.register_craft({
	output = "vaultnet_machines:grinder",
	recipe = {{S, "default:flint", S}, {C, "default:mese_crystal_fragment", C}, {S, S, S}},
})
core.register_craft({
	output = "vaultnet_machines:compressor",
	recipe = {{S, "default:stone", S}, {C, "default:mese_crystal_fragment", C}, {S, "default:stone", S}},
})
core.register_craft({
	output = "vaultnet_machines:alloy",
	recipe = {{S, "default:bronze_ingot", S}, {C, "default:furnace", C}, {S, "default:mese_crystal_fragment", S}},
})
