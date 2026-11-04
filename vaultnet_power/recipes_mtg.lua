-- Minetest Game recipes.

local S, G = "default:steel_ingot", "default:glass"
local V = function(n) return "vaultnet_components:" .. n end

core.register_craft({
	output = "vaultnet_power:generator",
	recipe = {
		{V"casing", V"coupler", V"casing"},
		{V"coil", "default:furnace", V"coil"},
		{S, V"circuit", S},
	},
})

core.register_craft({
	output = "vaultnet_power:solar",
	recipe = {
		{G, G, G},
		{V"circuit", V"circuit", V"circuit"},
		{V"coil", V"coupler", V"coil"},
	},
})
