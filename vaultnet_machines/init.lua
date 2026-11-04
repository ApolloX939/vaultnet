-- Processing machines: smelter, grinder, compressor and alloy furnace.
--
-- Like the autocrafter, a machine is set to ONE job: drop the input item(s) on its ghost
-- slot(s) (the alloy furnace has two). It then takes the inputs out of the network, works
-- for the recipe's time, and stores the results back. Nothing else in the network is
-- touched, so a machine never eats stock you did not point it at.
--
-- With vaultnet_require_power on a machine draws a little while idle and much more while
-- it works (so batteries help). It acts with its placer's rights on the core.

if core.settings:get_bool("vaultnet_machines_enabled", true) == false then
	core.log("action", "[vaultnet_machines] disabled by setting")
	return
end

vaultnet.machines = {}
local M = vaultnet.machines
local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/recipes.lua")

local SPEED = tonumber(core.settings:get("vaultnet_machines_speed")) or 1.0
local MULT = tonumber(core.settings:get("vaultnet_power_use_multiplier")) or 1.0
local INTERVAL = 1
local BUFFER_SLOTS = 9
local FORMNAME = "vaultnet_machines:machine"

local MACHINES = {
	smelter = {name = "Smelter", inputs = 1, idle = 1, work = 12, cooking = true},
	grinder = {name = "Grinder", inputs = 1, idle = 1, work = 10, rtype = "grinder"},
	compressor = {name = "Compressor", inputs = 1, idle = 1, work = 14, rtype = "compressor"},
	alloy = {name = "Alloy Furnace", inputs = 2, idle = 1, work = 12, rtype = "alloy"},
}
local ORDER = {"smelter", "grinder", "compressor", "alloy"}

local function node_name(id, active) return "vaultnet_machines:" .. id .. (active and "_active" or "") end

local machine_of = {} -- node name -> id
local all_names = {}

-- Recipes --------------------------------------------------------------------------------

-- {input = {{name, count}}, output = {ItemStack...}, time = s} for the machine's ghost slots.
local function resolve(id, inv)
	local m = MACHINES[id]
	local names = {}
	for i = 1, m.inputs do
		local s = inv:get_stack("inputs", i)
		if not s:is_empty() then names[#names + 1] = s:get_name() end
	end
	if #names ~= m.inputs then return nil end
	if m.cooking then
		local res = core.get_craft_result({method = "cooking", width = 1, items = {ItemStack(names[1])}})
		if not res or res.item:is_empty() then return nil end
		return {input = {{names[1], 1}}, output = {res.item}, time = res.time}
	end
	return M.lookup(m.rtype, names)
end

-- Network handling (same shape as the autocrafter) -----------------------------------------

local function set_status(pos, text)
	local meta = core.get_meta(pos)
	if meta:get_string("status") ~= text then
		meta:set_string("status", text)
		meta:set_string("infotext", "VaultNet machine\n" .. text)
	end
end

local function flush_buffer(net, inv, opts)
	for i = 1, BUFFER_SLOTS do
		local s = inv:get_stack("buffer", i)
		if not s:is_empty() then inv:set_stack("buffer", i, (net:insert(s, opts))) end
	end
	return inv:is_empty("buffer")
end

local function deliver(net, inv, opts, stacks, pos)
	for _, s in ipairs(stacks) do
		if not s:is_empty() then
			local left = net:insert(s, opts)
			if not left:is_empty() then left = inv:add_item("buffer", left) end
			if not left:is_empty() then core.add_item(pos, left) end
		end
	end
end

-- Take the recipe inputs out of the network; on failure everything is put back.
local function take_inputs(net, opts, r)
	local taken = {}
	for _, inp in ipairs(r.input) do
		local got = 0
		while got < inp[2] do
			local stack, err = net:extract_name(inp[1], inp[2] - got, opts)
			if err or stack:is_empty() then
				for _, s in ipairs(taken) do net:insert(s) end
				return false, inp[1]
			end
			taken[#taken + 1] = stack
			got = got + stack:get_count()
		end
	end
	return true
end

local function set_look(pos, node, id, active)
	local want = node_name(id, active)
	if node.name ~= want then
		node.name = want
		core.swap_node(pos, node)
	end
end

local function work(pos, node)
	local id = machine_of[node.name]
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()

	local function stop(text, keep_progress)
		meta:set_int("working", 0)
		if not keep_progress then meta:set_float("progress", 0) end
		set_status(pos, text)
		set_look(pos, node, id, false)
	end

	local net = vaultnet.get_network(pos)
	if not net or net:status() ~= "ok" then return stop("Network offline") end
	if not vaultnet.is_powered(pos) then return stop("No power") end
	local owner = meta:get_string("owner")
	local opts = owner ~= "" and {actor = owner} or {}

	if not flush_buffer(net, inv, opts) then return stop("Output blocked (network full?)", true) end
	local r = resolve(id, inv)
	if not r then return stop("No recipe set") end

	-- everything it needs must be in the network before it starts working
	local have = {}
	for _, e in ipairs(net:list()) do have[e.name] = (have[e.name] or 0) + e.count end
	for _, inp in ipairs(r.input) do
		if (have[inp[1]] or 0) < inp[2] then return stop("Missing: " .. inp[1]) end
	end

	meta:set_int("working", 1)
	local progress = meta:get_float("progress") + INTERVAL * SPEED
	if progress < r.time then
		meta:set_float("progress", progress)
		set_look(pos, node, id, true)
		return set_status(pos, ("Working %d%%"):format(math.floor(progress / r.time * 100)))
	end

	local ok, missing = take_inputs(net, opts, r)
	if not ok then return stop("Missing: " .. tostring(missing)) end
	local outputs = {}
	for i, s in ipairs(r.output) do outputs[i] = ItemStack(s) end
	deliver(net, inv, opts, outputs, pos)
	meta:set_float("progress", 0)
	set_look(pos, node, id, true)
	set_status(pos, "Working 0%")
end

core.register_abm({
	label = "VaultNet machine",
	nodenames = {"group:vaultnet_machine"},
	interval = INTERVAL,
	chance = 1,
	action = work,
})

-- Formspec ---------------------------------------------------------------------------------

local function build(pos, id)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local m = MACHINES[id]
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local esc = core.formspec_escape
	local r = resolve(id, inv)

	local fs = {
		"formspec_version[4]size[10.5,10.2]",
		("label[0.5,0.5;VaultNet %s]"):format(esc(m.name)),
		("list[nodemeta:%s;inputs;0.5,1;%d,1;]"):format(spos, m.inputs),
		("label[%f,1.6;->]"):format(0.5 + m.inputs * 1.25 + 0.2),
	}
	local x = 0.5 + m.inputs * 1.25 + 1.0
	if r then
		for i, out in ipairs(r.output) do
			fs[#fs + 1] = ("box[%f,1;1,1;#00000070]"):format(x)
			fs[#fs + 1] = ("item_image[%f,1;1,1;%s]"):format(x, esc(out:get_name()))
			fs[#fs + 1] = ("label[%f,2.3;%s]"):format(x, esc(("x%d"):format(out:get_count())))
			x = x + 1.25
		end
		local need = {}
		for _, inp in ipairs(r.input) do need[#need + 1] = ("%d x %s"):format(inp[2], inp[1]) end
		fs[#fs + 1] = ("label[0.5,3.1;Needs: %s   Time: %ds]"):format(esc(table.concat(need, ", ")), r.time)
	else
		fs[#fs + 1] = ("label[%f,1.6;No recipe]"):format(x)
	end
	fs[#fs + 1] = "label[0.5,3.6;Drop the input item(s) on the slot(s) to set the job. Click a slot to clear it.]"
	fs[#fs + 1] = ("label[0.5,4.0;Status: %s]"):format(esc(meta:get_string("status")))
	if not inv:is_empty("buffer") then
		fs[#fs + 1] = "label[7.0,0.8;Waiting to be stored:]"
		fs[#fs + 1] = ("list[nodemeta:%s;buffer;7.0,1;3,3;]"):format(spos)
	end
	fs[#fs + 1] = "list[current_player;main;0.5,4.8;8,4;]"
	fs[#fs + 1] = ("listring[nodemeta:%s;buffer]listring[current_player;main]"):format(spos)
	return table.concat(fs)
end

local function show(pos, name, id)
	core.show_formspec(name, FORMNAME, build(pos, id))
end

-- Nodes ------------------------------------------------------------------------------------

local function register(id, active)
	local m = MACHINES[id]
	local side = "vaultnet_machines_side.png"
	local name = node_name(id, active)
	core.register_node(name, {
		description = "VaultNet " .. m.name .. (active and " (active)" or ""),
		paramtype2 = "4dir",
		tiles = {("vaultnet_machines_%s_top.png"):format(id), side, side, side, side,
			active and {
				name = ("vaultnet_machines_%s_front_active.png"):format(id),
				animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.6},
			} or ("vaultnet_machines_%s_front.png"):format(id)},
		groups = {cracky = 2, vaultnet_device = 1, vaultnet_machine = 1,
			not_in_creative_inventory = active and 1 or nil},
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		light_source = active and 4 or nil,
		drop = node_name(id, false),
		vaultnet = {
			role = "machine",
			consumes_power = true,
			-- idle draw, much more while working
			power_draw = function(pos)
				local use = core.get_meta(pos):get_int("working") == 1 and m.work or m.idle
				return math.max(1, math.floor(use * MULT + 0.5))
			end,
		},
		on_construct = function(pos)
			local inv = core.get_meta(pos):get_inventory()
			inv:set_size("inputs", m.inputs)
			inv:set_size("buffer", BUFFER_SLOTS)
		end,
		after_place_node = function(pos, placer)
			if placer then core.get_meta(pos):set_string("owner", placer:get_player_name()) end
		end,
		on_rightclick = function(pos, _, clicker)
			if clicker and clicker:is_player() then show(pos, clicker:get_player_name(), id) end
		end,
		can_dig = function(pos)
			return core.get_meta(pos):get_inventory():is_empty("buffer")
		end,
		-- the input slots are "ghosts": dropping an item records its name only
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			local pname = player:get_player_name()
			if listname == "inputs" and not core.is_protected(pos, pname) then
				core.get_meta(pos):get_inventory():set_stack("inputs", index, ItemStack(stack:get_name()))
				core.get_meta(pos):set_float("progress", 0)
				show(pos, pname, id)
			end
			return 0
		end,
		allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			local pname = player:get_player_name()
			if core.is_protected(pos, pname) then return 0 end
			if listname == "inputs" then
				core.get_meta(pos):get_inventory():set_stack("inputs", index, ItemStack(""))
				core.get_meta(pos):set_float("progress", 0)
				show(pos, pname, id)
				return 0
			end
			return stack:get_count()
		end,
		allow_metadata_inventory_move = function() return 0 end,
	})
	machine_of[name] = id
	all_names[#all_names + 1] = name
end

for _, id in ipairs(ORDER) do
	register(id, false)
	register(id, true)
end

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
