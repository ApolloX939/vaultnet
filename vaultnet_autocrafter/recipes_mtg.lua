-- Minetest Game recipes.

local S, G, C = "default:steel_ingot", "default:glass", "default:copper_ingot"

core.register_craft({
	output = "vaultnet_autocrafter:autocrafter",
	recipe = {
		{S, G, S},
		{C, "default:mese_crystal", C},
		{S, "default:chest", S},
	},
})

-- Test recipe with a replacement (Minetest Game has none in the crafting grid):
-- a water bucket and sand make clay lumps and give the empty bucket back.
-- Enable with the setting `vaultnet_autocrafter_test_recipe`.
if core.settings:get_bool("vaultnet_autocrafter_test_recipe", false)
		and core.get_modpath("bucket") then
	core.register_craft({
		type = "shapeless",
		output = "default:clay_lump 2",
		recipe = {"bucket:bucket_water", "default:sand"},
		replacements = {{"bucket:bucket_water", "bucket:bucket_empty"}},
	})
end
