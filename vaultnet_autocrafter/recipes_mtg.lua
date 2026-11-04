-- Minetest Game recipes.

local V = function(n) return "vaultnet_components:" .. n end

core.register_craft({
	output = "vaultnet_autocrafter:autocrafter",
	recipe = {
		{V"casing", V"processor", V"casing"},
		{V"actuator", "default:chest", V"actuator"},
		{V"casing", V"circuit", V"casing"},
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
