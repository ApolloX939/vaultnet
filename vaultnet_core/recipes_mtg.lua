-- Minetest Game recipes.

local V = function(n) return "vaultnet_components:" .. n end

core.register_craft({
	output = "vaultnet_core:core",
	recipe = {
		{V"casing", V"processor", V"casing"},
		{V"circuit", V"resonator", V"circuit"},
		{V"casing", V"processor", V"casing"},
	},
})
