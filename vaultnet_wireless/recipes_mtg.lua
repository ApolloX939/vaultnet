-- Minetest Game recipes.

local S = "default:steel_ingot"
local V = function(n) return "vaultnet_components:" .. n end

core.register_craft({
	output = "vaultnet_wireless:relay",
	recipe = {
		{S, V"transceiver", S},
		{V"processor", V"casing", V"processor"},
		{S, V"coil", S},
	},
})
