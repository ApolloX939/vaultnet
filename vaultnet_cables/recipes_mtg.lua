-- Minetest Game recipes.

core.register_craft({
	output = "vaultnet_cables:cable 6",
	recipe = {
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
		{"default:copper_ingot", "default:copper_ingot", "default:copper_ingot"},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
	},
})

if vaultnet.require_power then
	core.register_craft({
		type = "shapeless",
		output = "vaultnet_cables:toggle_on",
		recipe = {"vaultnet_cables:cable", "default:mese_crystal_fragment"},
	})
end
