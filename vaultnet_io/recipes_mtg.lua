-- Minetest Game recipes.

local S, G = "default:steel_ingot", "default:glass"
local V = function(n) return "vaultnet_components:" .. n end

core.register_craft({
	output = "vaultnet_io:terminal",
	recipe = {
		{G, G, G},
		{V"circuit", V"processor", V"circuit"},
		{S, V"casing", S},
	},
})

core.register_craft({
	output = "vaultnet_io:inserter",
	recipe = {
		{S, V"circuit", S},
		{V"wire", V"actuator", V"wire"},
		{S, V"casing", S},
	},
})

core.register_craft({
	output = "vaultnet_io:exporter",
	recipe = {
		{S, V"casing", S},
		{V"wire", V"actuator", V"wire"},
		{S, V"circuit", S},
	},
})

-- Logistica-style devices are upgrades of the basic ones.
core.register_craft({
	type = "shapeless",
	output = "vaultnet_io:requester",
	recipe = {"vaultnet_io:exporter", V"processor"},
})

core.register_craft({
	type = "shapeless",
	output = "vaultnet_io:supplier",
	recipe = {"vaultnet_io:inserter", V"processor"},
})
