-- Game-specific materials for VaultNet's recipes: ONE place that says which item stands in for
-- each ingredient, per game.  The recipe files (recipes_mtg.lua in every sub-mod) are written with
-- Minetest Game ingredient names; `vaultnet.materials[game]` translates them for the running game.
--
--   vaultnet.materials.mtg   Minetest Game: the names are used as written (listed for reference).
--   vaultnet.materials.sbz   Skyblock: Zero: each MTG item mapped to an SBZ item (EMC = rough cost).
--
-- To change what a recipe needs, edit the value here; no recipe file needs touching.

local materials = {}
vaultnet.materials = materials

-- the ingredients the recipes use
local MTG_ITEMS = {
	"default:steel_ingot", "default:copper_ingot", "default:gold_ingot", "default:bronze_ingot",
	"default:glass", "default:paper", "default:coal_lump", "default:stone", "default:flint",
	"default:chest", "default:furnace",
	"default:mese_crystal_fragment", "default:mese_crystal", "default:mese",
	"default:diamond", "default:diamondblock",
}

materials.mtg = {}
for _, name in ipairs(MTG_ITEMS) do materials.mtg[name] = name end

materials.sbz = {
	-- metals
	["default:steel_ingot"]  = "sbz_chem:iron_ingot",              -- EMC 1.6   (casings, drives, bays: the bulk metal)
	["default:copper_ingot"] = "sbz_chem:copper_ingot",            -- EMC 1.6
	["default:gold_ingot"]   = "sbz_chem:gold_ingot",              -- EMC 1.6
	["default:bronze_ingot"] = "sbz_chem:bronze_ingot",            -- EMC 2.2

	-- basics
	["default:glass"]        = "sbz_resources:emittrium_glass",    -- EMC 4.4
	["default:paper"]        = "sbz_bio:paper",                    -- EMC 1
	["default:coal_lump"]    = "sbz_resources:matter_dust",        -- EMC 5     (capacitor only)
	["default:stone"]        = "sbz_resources:stone",              -- EMC 10.7  (compressor)
	["default:flint"]        = "sbz_resources:matter_dust",        -- EMC 5     (grinder)
	["default:chest"]        = "sbz_resources:storinator",         -- EMC 41    (autocrafter)
	["default:furnace"]      = "sbz_chem:simple_alloy_furnace_off", -- EMC 21.5 (smelter)

	-- the rare "mese" tier
	["default:mese_crystal_fragment"] = "sbz_resources:raw_emittrium", -- EMC 16
	["default:mese_crystal"] = "sbt:resium_crystal",               -- EMC 64
	["default:mese"]         = "sbz_resources:warp_crystal",       -- EMC 576   (storage cell 4, top drive)

	-- the very rare "diamond" tier
	["default:diamond"]      = "sbz_resources:phlogiston",         -- EMC 1024
	["default:diamondblock"] = "sbz_resources:phlogiston_blob",    -- EMC 8192  (SBZ has no diamond block)
}

-- Dig groups for VaultNet's nodes, per game. Every node gets `oddly_breakable_by_hand` as a universal
-- backup, so it can always be picked up even if a game's tools don't match the other groups.
--   mtg: cracky (pickaxes)
--   sbz: matter (the matter annihilator and the other Skyblock: Zero tools; a node without it can't be dug)
materials.groups = {
	mtg = { cracky = 2 },
	sbz = { matter = 1 },
}

-- The groups for a VaultNet node: the dig groups for the running game plus `extra` (which wins on a clash).
function vaultnet.groups(extra)
	local g = { cracky = 2, oddly_breakable_by_hand = 1 }
	for k, v in pairs(materials.groups[vaultnet.game() or "mtg"] or {}) do g[k] = v end
	for k, v in pairs(extra or {}) do g[k] = v end
	return g
end

-- the game VaultNet is running in: "mtg", "sbz" or nil (unknown)
function vaultnet.game()
	if core.get_modpath("default") then return "mtg" end
	if rawget(_G, "sbz_api") then return "sbz" end
end

local function translate(map, v)
	if type(v) == "string" then
		local name, rest = v:match("^(%S+)(.*)$")
		return name and map[name] and (map[name] .. rest) or v
	elseif type(v) == "table" then
		local out = {}
		for k, x in pairs(v) do out[k] = translate(map, x) end
		return out
	end
	return v
end
vaultnet.translate = function(game, v) return translate(materials[game] or {}, v) end

local function exists(name)
	if name == "" or name:match("^group:") then return true end
	return core.registered_items[ItemStack(name):get_name()] ~= nil
end

local function all_exist(v)
	if type(v) == "string" then return exists(v) end
	if type(v) == "table" then
		for _, x in pairs(v) do if not all_exist(x) then return false end end
	end
	return true
end

-- Run the sub-mods' recipes_mtg.lua with the ingredients translated for `game`. A recipe that would
-- still need a missing item (Technic / Techage alternatives, ...) is skipped.
-- Call it from a mod that loads after all the VaultNet sub-mods. Returns registered, skipped.
function vaultnet.register_recipes(game, modnames)
	local map = materials[game]
	assert(map, "vaultnet: no materials for game " .. tostring(game))

	core.register_on_mods_loaded(function()
		for from, to in pairs(map) do
			if not core.registered_items[to] then
				core.log("warning", ("[vaultnet] materials.%s: %s -> %s does not exist"):format(game, from, to))
			end
		end
	end)

	local registered, skipped = 0, 0
	local proxy = setmetatable({
		register_craft = function(def)
			def = translate(map, def)
			if not all_exist(def.output) or not all_exist(def.recipe) then
				skipped = skipped + 1
				return
			end
			core.register_craft(def)
			registered = registered + 1
		end,
	}, { __index = core })
	local env = setmetatable({ core = proxy, minetest = proxy }, { __index = _G })

	for _, name in ipairs(modnames) do
		local path = core.get_modpath(name)
		if path then
			local f, err = loadfile(path .. "/recipes_mtg.lua")
			if f then
				setfenv(f, env)
				local ok, e = pcall(f)
				if not ok then core.log("error", ("[vaultnet] %s recipes: %s"):format(name, tostring(e))) end
			else
				core.log("warning", ("[vaultnet] %s: %s"):format(name, tostring(err)))
			end
		end
	end

	core.log("action", ("[vaultnet] %s recipes: registered %d, skipped %d (need missing items)")
		:format(game, registered, skipped))
	return registered, skipped
end
