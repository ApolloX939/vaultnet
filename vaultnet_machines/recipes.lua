-- Recipe registry for the processing machines. A recipe has 1 or 2 inputs (item + count),
-- one or more outputs and a time in seconds. The smelter does not use this: it asks the
-- engine's cooking recipes.
--
--   vaultnet_machines.register_recipe("grinder", {
--       input = {"default:cobble"}, output = {"default:gravel"}, time = 3})
--   types: "grinder", "compressor", "alloy"

local M = vaultnet.machines
local recipes = {grinder = {}, compressor = {}, alloy = {}}
M.recipes = recipes

local function split(s)
	local stack = ItemStack(s)
	return stack:get_name(), stack:get_count()
end

local function index_of(inputs)
	local names = {}
	for i, inp in ipairs(inputs) do names[i] = inp[1] end
	table.sort(names)
	return table.concat(names, "/")
end

function M.register_recipe(rtype, def)
	local list = recipes[rtype]
	assert(list, "unknown recipe type " .. tostring(rtype))
	local inputs, outputs = {}, {}
	for i, s in ipairs(def.input) do
		local name, count = split(s)
		inputs[i] = {name, count}
	end
	table.sort(inputs, function(a, b) return a[1] < b[1] end)
	for i, s in ipairs(def.output) do outputs[i] = ItemStack(s) end
	list[index_of(inputs)] = {input = inputs, output = outputs, time = def.time or 3}
end

-- Recipe for the given input item names (any order), or nil.
function M.lookup(rtype, names)
	local sorted = {}
	for i, n in ipairs(names) do sorted[i] = n end
	table.sort(sorted)
	return recipes[rtype][table.concat(sorted, "/")]
end

-- Built in (Minetest Game) ---------------------------------------------------------------

if core.get_modpath("default") then
	local r = M.register_recipe
	r("grinder", {input = {"default:stone"}, output = {"default:cobble"}, time = 3})
	r("grinder", {input = {"default:cobble"}, output = {"default:gravel"}, time = 3})
	r("grinder", {input = {"default:gravel"}, output = {"default:sand"}, time = 3})
	r("grinder", {input = {"default:sandstone"}, output = {"default:sand 4"}, time = 3})
	for _, o in ipairs({"coal", "iron", "copper", "tin", "gold"}) do
		r("grinder", {input = {"default:stone_with_" .. o}, output = {"default:" .. o .. "_lump 2"}, time = 5})
	end
	r("grinder", {input = {"default:stone_with_diamond"}, output = {"default:diamond 2"}, time = 8})
	r("grinder", {input = {"default:stone_with_mese"}, output = {"default:mese_crystal 4"}, time = 8})

	r("compressor", {input = {"default:sand 2"}, output = {"default:sandstone"}, time = 4})
	r("compressor", {input = {"default:desert_sand 2"}, output = {"default:desert_sandstone"}, time = 4})
	r("compressor", {input = {"default:silver_sand 2"}, output = {"default:silver_sandstone"}, time = 4})
	r("compressor", {input = {"default:clay_lump 4"}, output = {"default:clay"}, time = 4})
	r("compressor", {input = {"default:snow 4"}, output = {"default:snowblock"}, time = 4})

	r("alloy", {input = {"default:copper_ingot 7", "default:tin_ingot"}, output = {"default:bronze_ingot 8"}, time = 6})
end

-- Technic -------------------------------------------------------------------------------

-- Technic's grinding, compressing and alloy recipes, once every mod has registered theirs.
core.register_on_mods_loaded(function()
	if not core.settings:get_bool("vaultnet_machines_import_technic", true) then return end
	if not rawget(_G, "technic") or not technic.recipes then return end
	local count = 0
	for ttype, ours in pairs({grinding = "grinder", compressing = "compressor", alloy = "alloy"}) do
		local set = technic.recipes[ttype]
		for _, rec in pairs(set and set.recipes or {}) do
			local out = type(rec.output) == "table" and rec.output or {rec.output}
			if #rec.input >= 1 and #rec.input <= 2 and #out >= 1 then
				local ok = pcall(M.register_recipe, ours, {input = rec.input, output = out, time = rec.time})
				if ok then count = count + 1 end
			end
		end
	end
	core.log("action", ("[vaultnet_machines] imported %d Technic recipes"):format(count))
end)
