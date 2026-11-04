-- Minetest Game recipes for the machines themselves.

local S = "default:steel_ingot"
local V = function(n) return "vaultnet_components:" .. n end

core.register_craft({
	output = "vaultnet_machines:smelter",
	recipe = {
		{V"casing", "default:furnace", V"casing"},
		{V"coil", V"circuit", V"coil"},
		{S, S, S},
	},
})
core.register_craft({
	output = "vaultnet_machines:grinder",
	recipe = {
		{V"casing", "default:flint", V"casing"},
		{V"actuator", V"circuit", V"actuator"},
		{S, S, S},
	},
})
core.register_craft({
	output = "vaultnet_machines:compressor",
	recipe = {
		{V"casing", V"actuator", V"casing"},
		{"default:stone", V"circuit", "default:stone"},
		{S, S, S},
	},
})
core.register_craft({
	output = "vaultnet_machines:alloy",
	recipe = {
		{V"casing", "default:furnace", V"casing"},
		{V"coil", V"circuit", V"coil"},
		{"default:bronze_ingot", S, "default:bronze_ingot"},
	},
})
