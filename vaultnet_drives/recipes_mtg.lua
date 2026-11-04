-- Minetest Game recipes. Tiers are crafted from components and raw materials (never
-- from a lower drive) so no stored contents can be lost in a craft.
--   {S, top, S}
--   {S, cell, S}
--   {X, casing, Y}
-- top: glass -> circuit -> processor as the tiers grow; the cell grade grows every few
-- tiers; X and Y climb from copper through gold, mese and diamond to the blocks.

local S, G = "default:steel_ingot", "default:glass"
local V = function(n) return "vaultnet_components:" .. n end

local C, GOLD = "default:copper_ingot", "default:gold_ingot"
local CR, D = "default:mese_crystal", "default:diamond"
local MB, DB = "default:mese", "default:diamondblock"

local TIERS = {
	{G, V"cell_1", C, C},
	{G, V"cell_1", C, GOLD},
	{G, V"cell_1", GOLD, GOLD},
	{V"circuit", V"cell_2", GOLD, CR},
	{V"circuit", V"cell_2", CR, CR},
	{V"circuit", V"cell_2", CR, D},
	{V"processor", V"cell_3", D, D},
	{V"processor", V"cell_3", D, MB},
	{V"processor", V"cell_3", MB, DB},
	{V"processor", V"cell_4", DB, DB},
}

for i, t in ipairs(TIERS) do
	core.register_craft({
		output = "vaultnet_drives:drive" .. i,
		recipe = {
			{S, t[1], S},
			{S, t[2], S},
			{t[3], V"casing", t[4]},
		},
	})
end

core.register_craft({
	output = "vaultnet_drives:bay",
	recipe = {
		{S, V"circuit", S},
		{V"actuator", V"casing", V"actuator"},
		{S, V"circuit", S},
	},
})
