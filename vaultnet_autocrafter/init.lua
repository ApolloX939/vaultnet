-- Autocrafter: crafts one fixed 3x3 recipe over and over using items from the
-- network, and stores the results (and any recipe replacements) back.
--
--  * Set the recipe by dropping items on the 3x3 grid (ghost slots: only the item
--    name is recorded). Shaped and shapeless recipes both work, as long as they fit
--    the 3x3 grid.
--  * Each craft takes one of each ingredient out of the network (any stored variant
--    of that item), runs the engine's own craft lookup, and inserts the output.
--  * Acts with its placer's rights on the core: it needs "pull" and "put".
--  * Output the network cannot take is parked in the autocrafter's buffer and the
--    crafter pauses until it has been moved on.

if core.settings:get_bool("vaultnet_autocrafter_enabled", true) == false then
	core.log("action", "[vaultnet_autocrafter] disabled by setting")
	return
end

local modpath = core.get_modpath(core.get_current_modname())
local INTERVAL = tonumber(core.settings:get("vaultnet_autocrafter_interval")) or 1.0
local FORMNAME = "vaultnet_autocrafter:crafter"
local IDLE, ACTIVE = "vaultnet_autocrafter:autocrafter", "vaultnet_autocrafter:autocrafter_active"
local BUFFER_SLOTS = 9

-- Recipe -----------------------------------------------------------------------

local function grid_from(inv)
	local items = {}
	for i = 1, 9 do items[i] = inv:get_stack("recipe", i) end
	return items
end

-- The engine's result for a grid: output ItemStack (empty if no recipe), plus the
-- full result tables.
local function lookup(items)
	local out, dec = core.get_craft_result({method = "normal", width = 3, items = items})
	return out.item, out, dec
end

-- Ingredient counts of a grid by item name.
local function needs(items)
	local n = {}
	for _, s in ipairs(items) do
		if not s:is_empty() then n[s:get_name()] = (n[s:get_name()] or 0) + 1 end
	end
	return n
end

-- Crafting ------------------------------------------------------------------------

local function set_status(pos, text)
	local meta = core.get_meta(pos)
	if meta:get_string("status") ~= text then
		meta:set_string("status", text)
		meta:set_string("infotext", "VaultNet Autocrafter\n" .. text)
	end
end

-- Move what is parked in the buffer into the network. True when it is empty.
local function flush_buffer(net, inv, opts)
	for i = 1, BUFFER_SLOTS do
		local s = inv:get_stack("buffer", i)
		if not s:is_empty() then
			inv:set_stack("buffer", i, (net:insert(s, opts)))
		end
	end
	return inv:is_empty("buffer")
end

local function deliver(net, inv, opts, stacks, pos)
	for _, s in ipairs(stacks) do
		if not s:is_empty() then
			local left = net:insert(s, opts)
			if not left:is_empty() then left = inv:add_item("buffer", left) end
			if not left:is_empty() then core.add_item(pos, left) end -- last resort
		end
	end
end

local function craft_once(pos, net, inv, opts)
	local grid = grid_from(inv)
	local result = lookup(grid)
	if result:is_empty() then return false, "No recipe set" end

	-- check the network holds everything before touching it
	local have = {}
	for _, e in ipairs(net:list()) do have[e.name] = (have[e.name] or 0) + e.count end
	for name, n in pairs(needs(grid)) do
		if (have[name] or 0) < n then return false, "Missing: " .. name end
	end

	-- take one of each ingredient, remembering the real stacks (they may carry meta)
	local taken, real = {}, {}
	local ok, missing = true, nil
	for i, g in ipairs(grid) do
		if g:is_empty() then
			real[i] = ItemStack()
		else
			local stack, err = net:extract_name(g:get_name(), 1, opts)
			if err or stack:is_empty() then
				ok, missing = false, err and ("Network: " .. err) or ("Missing: " .. g:get_name())
				break
			end
			real[i] = stack
			taken[#taken + 1] = stack
		end
	end
	if not ok then
		for _, s in ipairs(taken) do net:insert(s) end -- put everything back
		return false, missing
	end

	local out, full, dec = lookup(real)
	if out:is_empty() then
		for _, s in ipairs(taken) do net:insert(s) end
		return false, "No recipe set"
	end
	local outputs = {out}
	for _, r in ipairs(full.replacements or {}) do outputs[#outputs + 1] = r end
	for _, s in ipairs(dec.items) do outputs[#outputs + 1] = s end
	deliver(net, inv, opts, outputs, pos)
	return true
end

local function run(pos, node)
	local meta = core.get_meta(pos)
	local net = vaultnet.get_network(pos)
	if not net or net:status() ~= "ok" then return set_status(pos, "Network offline") end

	local owner = meta:get_string("owner")
	local opts = owner ~= "" and {actor = owner} or {}
	local inv = meta:get_inventory()

	if not flush_buffer(net, inv, opts) then
		return set_status(pos, "Output blocked (network full?)")
	end
	local ok, why = craft_once(pos, net, inv, opts)
	set_status(pos, ok and "Crafting" or why)
end

local ALL_NODES = {IDLE, ACTIVE}
core.register_abm({
	label = "VaultNet autocrafter",
	nodenames = ALL_NODES,
	interval = INTERVAL,
	chance = 1,
	action = run,
})

-- Formspec ------------------------------------------------------------------------

local function build(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local esc = core.formspec_escape
	local result = lookup(grid_from(inv))

	local fs = {
		"formspec_version[4]size[10.5,10.8]",
		"label[0.5,0.5;VaultNet Autocrafter]",
		("list[nodemeta:%s;recipe;0.5,1;3,3;]"):format(spos),
		"label[4.4,2.8;->]",
		"box[5.2,2.3;1,1;#00000070]",
	}
	if result:is_empty() then
		fs[#fs + 1] = "label[5.0,3.7;No recipe]"
	else
		fs[#fs + 1] = ("item_image[5.2,2.3;1,1;%s]"):format(esc(result:get_name()))
		fs[#fs + 1] = ("label[5.0,3.7;%s x%d]"):format(esc(result:get_name()), result:get_count())
	end
	fs[#fs + 1] = "label[0.5,4.9;Drop items on the grid to set the recipe. Click a slot to clear it.]"
	fs[#fs + 1] = ("label[0.5,5.3;Status: %s]"):format(esc(meta:get_string("status")))
	if not inv:is_empty("buffer") then
		fs[#fs + 1] = "label[7.0,0.8;Waiting to be stored:]"
		fs[#fs + 1] = ("list[nodemeta:%s;buffer;7.0,1;3,3;]"):format(spos)
	end
	fs[#fs + 1] = "list[current_player;main;0.5,5.9;8,4;]"
	fs[#fs + 1] = ("listring[nodemeta:%s;buffer]listring[current_player;main]"):format(spos)
	return table.concat(fs)
end

local function show(pos, name)
	core.show_formspec(name, FORMNAME, build(pos))
end

-- Nodes -----------------------------------------------------------------------------

local function register(name, desc, front, vn, extra)
	local side = "vaultnet_autocrafter_side.png"
	local def = {
		description = desc,
		paramtype2 = "4dir",
		tiles = {"vaultnet_autocrafter_top.png", side, side, side, side, front},
		groups = {cracky = 2, vaultnet_device = 1},
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		vaultnet = vn,

		on_construct = function(pos)
			local inv = core.get_meta(pos):get_inventory()
			inv:set_size("recipe", 9)
			inv:set_size("buffer", BUFFER_SLOTS)
		end,
		after_place_node = function(pos, placer)
			if placer then core.get_meta(pos):set_string("owner", placer:get_player_name()) end
		end,
		on_rightclick = function(pos, _, clicker)
			if clicker and clicker:is_player() then show(pos, clicker:get_player_name()) end
		end,
		can_dig = function(pos)
			return core.get_meta(pos):get_inventory():is_empty("buffer")
		end,

		-- recipe slots are "ghosts": dropping an item records its name only
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			local pname = player:get_player_name()
			if listname == "recipe" and not core.is_protected(pos, pname) then
				core.get_meta(pos):get_inventory():set_stack("recipe", index, ItemStack(stack:get_name()))
				show(pos, pname)
			end
			return 0
		end,
		allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			local pname = player:get_player_name()
			if core.is_protected(pos, pname) then return 0 end
			if listname == "recipe" then
				core.get_meta(pos):get_inventory():set_stack("recipe", index, ItemStack(""))
				show(pos, pname)
				return 0
			end
			return stack:get_count() -- buffer: let the player rescue stuck output
		end,
		allow_metadata_inventory_move = function() return 0 end,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_node(name, def)
end

register(IDLE, "VaultNet Autocrafter", "vaultnet_autocrafter_front.png", {
	role = "autocrafter",
	active_variant = ACTIVE,
})

register(ACTIVE, "VaultNet Autocrafter (active)", {
	name = "vaultnet_autocrafter_front_active.png",
	animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 2.7},
}, {
	role = "autocrafter",
	inactive_variant = IDLE,
}, {
	drop = IDLE,
	light_source = 3,
	groups = {cracky = 2, vaultnet_device = 1, not_in_creative_inventory = 1},
})

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
