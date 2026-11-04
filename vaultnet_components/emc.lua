-- EMC (https://codeberg.org/F3mboyPhoenix/emc) support, used when that mod is installed.
--
-- The EMC mod prices an item from the first crafting recipe it can solve. A component with
-- alternative recipes (Technic / Techage parts) would then be priced by whichever recipe
-- the solver happens to reach first, and a cheap alternative (a Technic battery for a
-- capacitor) makes the component, and everything built from it, far cheaper than its own
-- recipe says. So after the solver has run, the components are re-priced from their OWN
-- recipes, and every other VaultNet item is re-priced from its recipe on top of those.

local OWN = vaultnet_components.recipes

local function count_ingredients(recipe)
	local counts = {}
	for _, row in ipairs(recipe) do
		for _, name in ipairs(row) do
			if name ~= "" then counts[name] = (counts[name] or 0) + 1 end
		end
	end
	return counts
end

-- value of one output of a recipe with ingredient counts, or nil if one is unpriced
local function price(counts, out_count)
	local total = 0
	for name, n in pairs(counts) do
		local v = emc.get(name)
		if not v then return nil end
		total = total + v * n
	end
	return math.max(1, math.floor(total / out_count))
end

-- Base items VaultNet recipes use, with the value the EMC mod gives them in a plain Minetest
-- Game world. A world where something changes how they are made (Techage turns iron and
-- bronze into its own chain, which the EMC mod does not know) would leave them unpriced and,
-- with them, every VaultNet item; they only get these values when they have none.
local FALLBACK = {
	["default:steel_ingot"] = 256, ["default:copper_ingot"] = 64, ["default:gold_ingot"] = 512,
	["default:bronze_ingot"] = 60, ["default:paper"] = 9, ["default:glass"] = 1,
	["default:mese_crystal_fragment"] = 111, ["default:mese_crystal"] = 1000, ["default:mese"] = 9000,
	["default:diamond"] = 1024, ["default:diamondblock"] = 9216, ["default:coal_lump"] = 128,
	["default:chest"] = 32, ["default:furnace"] = 8, ["default:flint"] = 2, ["default:stone"] = 1,
}

emc.register_after_solver_fn(function()
	for name, value in pairs(FALLBACK) do
		if core.registered_items[name] and not emc.has(name) then emc.set(name, value) end
	end

	-- 1. components from their own recipes, in the order they are declared (each only
	--    needs base items or earlier components)
	local is_component = {}
	for _, r in ipairs(OWN) do
		is_component[r.output] = true
		local v = price(count_ingredients(r.recipe), r.count)
		if v then emc.set(r.output, v) end
	end

	-- 2. every other VaultNet item with a recipe, from that recipe (repeat until stable:
	--    some are built from other VaultNet items)
	local items = {}
	for name, def in pairs(core.registered_items) do
		if name:match("^vaultnet_") and not is_component[name]
				and (def.groups or {}).not_in_creative_inventory ~= 1 then
			items[#items + 1] = name
		end
	end
	table.sort(items)
	for _ = 1, 8 do
		local changed = false
		for _, name in ipairs(items) do
			for _, recipe in ipairs(core.get_all_craft_recipes(name) or {}) do
				if recipe.method == "normal" then
					local counts = {}
					for _, it in pairs(recipe.items or {}) do
						local s = ItemStack(it)
						if not s:is_empty() then counts[s:get_name()] = (counts[s:get_name()] or 0) + s:get_count() end
					end
					local v = price(counts, ItemStack(recipe.output):get_count())
					if v and v ~= emc.get(name) then emc.set(name, v); changed = true end
					if v then break end
				end
			end
		end
		if not changed then break end
	end
end)
