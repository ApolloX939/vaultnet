-- Minetest Game recipes.

local S = "default:steel_ingot"
local V = function(n) return "vaultnet_components:" .. n end

core.register_craft({
	output = "vaultnet_cables:cable 6",
	recipe = {
		{S, S, S},
		{V"wire", V"wire", V"wire"},
		{S, S, S},
	},
})

if vaultnet.require_power then
	core.register_craft({
		type = "shapeless",
		output = "vaultnet_cables:toggle_on",
		recipe = {"vaultnet_cables:cable", V"circuit"},
	})
end
