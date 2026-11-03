-- Minetest Game recipes. Tiers are crafted from raw materials (never from a
-- lower drive) so no stored contents can be lost in a craft.
-- Layout: {X, glass, X} / {steel, core, steel} / {steel, copper, steel}

local S, G, C = "default:steel_ingot", "default:glass", "default:copper_ingot"

-- {X, core} per tier
local TIERS = {
	{S, "default:mese_crystal_fragment"},
	{"default:bronze_ingot", "default:mese_crystal_fragment"},
	{S, "default:mese_crystal"},
	{"default:bronze_ingot", "default:mese_crystal"},
	{"default:gold_ingot", "default:mese_crystal"},
	{"default:gold_ingot", "default:diamond"},
	{"default:mese_crystal", "default:diamond"},
	{"default:diamond", "default:mese"},
	{"default:mese", "default:diamondblock"},
	{"default:diamondblock", "default:mese"},
}

for i, t in ipairs(TIERS) do
	core.register_craft({
		output = "vaultnet_drives:drive" .. i,
		recipe = {
			{t[1], G, t[1]},
			{S, t[2], S},
			{S, C, S},
		},
	})
end
