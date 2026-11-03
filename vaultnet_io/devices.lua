-- Inserter and Exporter.
--
--  Inserter: target inventory -> network.   Exporter: network -> target inventory.
--
-- Place the device against a node: it points at that node (wallmounted, so the
-- target is the node it is attached to). Right-click opens the configuration:
-- a non-interactive preview of the target's inventory layout where you click the
-- inventory lists to use, an amount per transfer and an item filter.
--
-- A device acts with its owner's rights on the core (put / pull) and respects
-- area protection on the target.

local A = vaultnet.access

local INTERVAL = tonumber(core.settings:get("vaultnet_io_interval")) or 1.0
local DEFAULT_AMOUNT = tonumber(core.settings:get("vaultnet_io_default_amount")) or 16
local AMOUNTS = {1, 4, 16, 64}
local FILTER_SLOTS = 8
local FORMNAME = "vaultnet_io:device"

local FULL = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
local BOX = {
	type = "wallmounted",
	wall_bottom = {-0.4, -0.5, -0.4, 0.4, 0.4, 0.4},
	wall_top = {-0.4, -0.4, -0.4, 0.4, 0.5, 0.4},
	wall_side = {-0.5, -0.4, -0.4, 0.4, 0.4, 0.4},
}

local KINDS = {
	inserter = {name = "Inserter", node = "vaultnet_io:inserter", active = "vaultnet_io:inserter_active"},
	exporter = {name = "Exporter", node = "vaultnet_io:exporter", active = "vaultnet_io:exporter_active"},
}
local kind_of = {} -- node name -> kind
for kind, k in pairs(KINDS) do
	kind_of[k.node] = kind
	kind_of[k.active] = kind
end

-- Meta helpers ------------------------------------------------------------------

local function get_lists_set(meta)
	local s = meta:get_string("lists")
	return s ~= "" and core.deserialize(s) or {}
end

local function set_lists_set(meta, set)
	meta:set_string("lists", core.serialize(set))
end

local function get_amount(meta)
	local a = meta:get_int("amount")
	return a > 0 and a or DEFAULT_AMOUNT
end

-- Item name filter. Returns function(name) -> bool.
local function make_filter(meta)
	local inv = meta:get_inventory()
	local names, any = {}, false
	for i = 1, FILTER_SLOTS do
		local s = inv:get_stack("filter", i)
		if not s:is_empty() then names[s:get_name()] = true; any = true end
	end
	if not any then return function() return true end end
	if meta:get_string("filter_mode") == "deny" then
		return function(name) return not names[name] end
	end
	return function(name) return names[name] == true end
end

local function target_pos(pos, node)
	local dir = core.wallmounted_to_dir(node.param2)
	return {x = pos.x + dir.x, y = pos.y + dir.y, z = pos.z + dir.z}
end

local function target_lists(tpos)
	local inv = core.get_meta(tpos):get_inventory()
	local out = {}
	for name in pairs(inv:get_lists()) do out[#out + 1] = name end
	table.sort(out)
	return out, inv
end

-- Transfers -----------------------------------------------------------------------

local function wake_target(tpos)
	local def = core.registered_nodes[core.get_node(tpos).name]
	if def and def.on_timer then
		local t = core.get_node_timer(tpos)
		if not t:is_started() then t:start(1.0) end
	end
end

-- Target inventory -> network. Returns number of items moved.
local function do_insert(net, opts, tinv, lists, allow, budget)
	local moved = 0
	for _, lname in ipairs(lists) do
		local size = tinv:get_size(lname)
		for i = 1, size do
			if budget <= 0 then return moved end
			local stack = tinv:get_stack(lname, i)
			if not stack:is_empty() and allow(stack:get_name())
					and not vaultnet.drive.is_drive(stack) then
				local want = math.min(stack:get_count(), budget)
				local part = stack:take_item(want)
				local leftover = net:insert(part, opts)
				local stored = part:get_count() - leftover:get_count()
				if not leftover:is_empty() then stack:add_item(leftover) end
				tinv:set_stack(lname, i, stack)
				moved, budget = moved + stored, budget - stored
				if not leftover:is_empty() then return moved end -- network full
			end
		end
	end
	return moved
end

-- Network -> target inventory.
local function do_export(net, opts, tinv, lists, allow, budget)
	local moved = 0
	for _, entry in ipairs(net:list()) do
		if budget <= 0 then break end
		if allow(entry.name) then
			-- skip items no selected list has room for
			local probe = vaultnet.key_to_stack(entry.key, 1)
			local fits = false
			for _, lname in ipairs(lists) do
				if tinv:room_for_item(lname, probe) then fits = true break end
			end
			if fits then
				local want = math.min(budget, entry.count, probe:get_stack_max())
				local stack, err = net:extract_key(entry.key, want, opts)
				if err then return moved end
				local got = stack:get_count()
				for _, lname in ipairs(lists) do
					if stack:is_empty() then break end
					stack = tinv:add_item(lname, stack)
				end
				local given = got - stack:get_count()
				if not stack:is_empty() then net:insert(stack) end -- put back what did not fit
				moved, budget = moved + given, budget - given
			end
		end
	end
	return moved
end

local function set_info(pos, kind, text)
	local meta = core.get_meta(pos)
	local full = ("VaultNet %s\n%s"):format(KINDS[kind].name, text)
	if meta:get_string("infotext") ~= full then meta:set_string("infotext", full) end
end

local function run(pos, node)
	local kind = kind_of[node.name]
	if not kind then return end
	local meta = core.get_meta(pos)

	local net = vaultnet.get_network(pos)
	if not net or net:status() ~= "ok" then
		return set_info(pos, kind, "Network offline")
	end
	local tpos = target_pos(pos, node)
	if not core.get_node_or_nil(tpos) then return end
	local lists_set = get_lists_set(meta)
	local lists = {}
	local tlists, tinv = target_lists(tpos)
	for _, name in ipairs(tlists) do
		if lists_set[name] then lists[#lists + 1] = name end
	end
	if #tlists == 0 then return set_info(pos, kind, "Nothing to connect to") end
	if #lists == 0 then return set_info(pos, kind, "No inventory selected") end

	local owner = meta:get_string("owner")
	if owner ~= "" and core.is_protected(tpos, owner) then
		return set_info(pos, kind, "Target is protected")
	end
	local opts = owner ~= "" and {actor = owner} or {}

	local allow = make_filter(meta)
	local budget = get_amount(meta)
	local moved
	if kind == "inserter" then
		moved = do_insert(net, opts, tinv, lists, allow, budget)
	else
		moved = do_export(net, opts, tinv, lists, allow, budget)
		if moved > 0 then wake_target(tpos) end
	end
	set_info(pos, kind, moved > 0 and "Working" or "Idle")
end

core.register_abm({
	label = "VaultNet inserter/exporter",
	nodenames = {"vaultnet_io:inserter", "vaultnet_io:inserter_active",
		"vaultnet_io:exporter", "vaultnet_io:exporter_active"},
	interval = INTERVAL,
	chance = 1,
	action = run,
})

-- Configuration formspec ------------------------------------------------------------

local contexts = {} -- player -> {pos, lists = {names}}
local PREV_X, PREV_Y, PREV_W, PREV_H = 0.5, 1.7, 9.6, 3.6
local PITCH = 1.25

-- Parse the list[] elements out of the target's formspec string. Returns an
-- array of {name, x, y, w, h, start} in preview units, or {} when none found.
local function parse_layout(tpos, existing)
	local fs = core.get_meta(tpos):get_string("formspec")
	local found, seen = {}, {}
	if fs == "" then return found end
	local version = tonumber(fs:match("formspec_version%[(%d+)%]")) or 1
	local scale = version >= 2 and 1 or PITCH
	for body in fs:gmatch("list%[(.-)%]") do
		local loc, name, pos_s, size_s, start =
			body:match("^([^;]*);([^;]*);([^;]*);([^;]*);?([^;]*)$")
		if loc and name and not seen[name] and existing[name]
				and (loc == "context" or loc == "current_name" or loc:find("^nodemeta:")) then
			local x, y = pos_s:match("^%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)")
			local w, h = size_s:match("^%s*(%d+)%s*,%s*(%d+)")
			if x and y and w and h then
				seen[name] = true
				found[#found + 1] = {name = name, x = tonumber(x) * scale, y = tonumber(y) * scale,
					w = tonumber(w), h = tonumber(h), start = tonumber(start) or 0}
			end
		end
	end
	return found
end

-- Fallback layout: every list as a wrapped grid, stacked vertically.
local function fallback_layout(tlists, tinv)
	local out, y = {}, 0.4
	for _, name in ipairs(tlists) do
		local size = math.min(tinv:get_size(name), 64)
		local w = math.max(1, math.min(size, 8))
		local h = math.max(1, math.ceil(size / w))
		out[#out + 1] = {name = name, x = 0, y = y, w = w, h = h, start = 0}
		y = y + h * PITCH + 0.5
	end
	return out
end

local function build(pos, player_name)
	local node = core.get_node(pos)
	local kind = kind_of[node.name]
	local meta = core.get_meta(pos)
	local tpos = target_pos(pos, node)
	local tnode = core.get_node_or_nil(tpos)
	local esc = core.formspec_escape
	local tlists, tinv = {}, nil
	if tnode then tlists, tinv = target_lists(tpos) end
	local existing = {}
	for _, n in ipairs(tlists) do existing[n] = true end

	local sel = get_lists_set(meta)
	-- convenient default: a single inventory list is selected for you
	if next(sel) == nil and #tlists == 1 then
		sel[tlists[1]] = true
		set_lists_set(meta, sel)
	end
	contexts[player_name] = {pos = pos, lists = tlists}

	local tdef = tnode and core.registered_nodes[tnode.name]
	local tdesc = tdef and (tdef.short_description or tdef.description) or "unknown"
	if tdesc == "" and tnode then tdesc = tnode.name end

	local fs = {
		"formspec_version[4]size[12,13.4]",
		("label[0.5,0.5;VaultNet %s]"):format(KINDS[kind].name),
		("label[0.5,1.0;%s]"):format(esc(kind == "inserter"
			and ("Takes from: %s (%d,%d,%d) into the network"):format(core.strip_colors(tdesc), tpos.x, tpos.y, tpos.z)
			or ("Puts into: %s (%d,%d,%d) from the network"):format(core.strip_colors(tdesc), tpos.x, tpos.y, tpos.z))),
	}

	if #tlists == 0 then
		fs[#fs + 1] = "label[0.5,2.2;The node this device points at has no inventory.]"
		return table.concat(fs)
	end
	fs[#fs + 1] = "label[0.5,1.45;Click an inventory below (or tick it on the right) to use it.]"

	-- preview ---------------------------------------------------------------
	local layout = parse_layout(tpos, existing)
	local note = ""
	if #layout == 0 then layout = fallback_layout(tlists, tinv); note = "(layout unknown)" end
	local index_of = {}
	for i, n in ipairs(tlists) do index_of[n] = i end

	local content_h = 0
	for _, l in ipairs(layout) do
		content_h = math.max(content_h, l.y + l.h * PITCH)
	end
	fs[#fs + 1] = ("box[%f,%f;%f,%f;#00000060]"):format(PREV_X - 0.1, PREV_Y - 0.1, PREV_W + 0.2, PREV_H + 0.2)
	fs[#fs + 1] = ("scroll_container[%f,%f;%f,%f;prev_sb;vertical;0.1]"):format(PREV_X, PREV_Y, PREV_W, PREV_H)
	for _, l in ipairs(layout) do
		local i = index_of[l.name]
		local selected = sel[l.name]
		local W, H = l.w * PITCH - 0.25, l.h * PITCH - 0.25
		fs[#fs + 1] = ("box[%f,%f;%f,%f;%s]"):format(l.x - 0.1, l.y - 0.1, W + 0.2, H + 0.2,
			selected and "#40ff4090" or "#ffffff18")
		for r = 0, l.h - 1 do
			for c = 0, l.w - 1 do
				local n = r * l.w + c
				if n >= 64 then break end
				local sx, sy = l.x + c * PITCH, l.y + r * PITCH
				fs[#fs + 1] = ("box[%f,%f;1,1;#00000070]"):format(sx, sy)
				local st = tinv:get_stack(l.name, l.start + n + 1)
				if not st:is_empty() then
					fs[#fs + 1] = ("item_image[%f,%f;1,1;%s]"):format(sx, sy, esc(st:get_name()))
				end
			end
		end
		fs[#fs + 1] = ("label[%f,%f;%s]"):format(l.x, l.y - 0.22, esc(l.name))
		fs[#fs + 1] = ("style[sel_%d;bgcolor=#00000000;bgcolor_hovered=#ffffff30;bgcolor_pressed=#ffffff50;border=false]"):format(i)
		fs[#fs + 1] = ("button[%f,%f;%f,%f;sel_%d;]"):format(l.x, l.y, W, H, i)
		fs[#fs + 1] = ("tooltip[sel_%d;%s]"):format(i, esc(l.name .. (selected and " (selected)" or "")))
	end
	fs[#fs + 1] = "scroll_container_end[]"
	local max = math.max(0, math.ceil((content_h - PREV_H) * 10))
	fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=12;largestep=36]"):format(max)
	fs[#fs + 1] = ("scrollbar[%f,%f;0.3,%f;vertical;prev_sb;0]"):format(PREV_X + PREV_W + 0.15, PREV_Y, PREV_H)

	-- checkbox column (reliable even if the preview layout is odd)
	fs[#fs + 1] = "label[10.6,1.9;Inventories]"
	for i, n in ipairs(tlists) do
		if i > 12 then break end
		fs[#fs + 1] = ("checkbox[10.6,%f;use_%d;%s;%s]"):format(2.3 + (i - 1) * 0.45, i, esc(n),
			sel[n] and "true" or "false")
	end
	if note ~= "" then fs[#fs + 1] = ("label[0.5,5.55;%s]"):format(note) end

	-- settings --------------------------------------------------------------
	local amount = get_amount(meta)
	local aidx = 3
	for i, a in ipairs(AMOUNTS) do if a == amount then aidx = i end end
	fs[#fs + 1] = "label[0.5,6.0;Items per transfer]"
	fs[#fs + 1] = ("dropdown[0.5,6.2;2,0.7;amount;%s;%d]"):format(table.concat(AMOUNTS, ","), aidx)
	fs[#fs + 1] = "label[3.0,6.0;Filter]"
	fs[#fs + 1] = ("dropdown[3.0,6.2;3.4,0.7;filter_mode;Only these items,Everything except these;%d]"):format(
		meta:get_string("filter_mode") == "deny" and 2 or 1)
	fs[#fs + 1] = ("list[context;filter;0.5,7.4;%d,1;]"):format(FILTER_SLOTS)
	fs[#fs + 1] = "label[0.5,7.2;Drop items on the slots to set the filter (empty = everything). Click a slot to clear it.]"
	fs[#fs + 1] = "list[current_player;main;0.5,8.9;8,4;]"
	fs[#fs + 1] = ("listring[nodemeta:%d,%d,%d;filter]listring[current_player;main]"):format(pos.x, pos.y, pos.z)
	return (table.concat(fs):gsub("list%[context;filter;", ("list[nodemeta:%d,%d,%d;filter;"):format(pos.x, pos.y, pos.z)))
end

local function show(pos, name)
	core.show_formspec(name, FORMNAME, build(pos, name))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then return end
	local name = player:get_player_name()
	local ctx = contexts[name]
	if fields.quit then
		contexts[name] = nil
		return true
	end
	if not ctx then return true end
	local pos = ctx.pos
	local node = core.get_node_or_nil(pos)
	if not node or not kind_of[node.name] then return true end
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return true
	end
	local meta = core.get_meta(pos)

	local sel = get_lists_set(meta)
	local changed = false
	-- checkboxes first (apply only real changes), then preview clicks
	for i, lname in ipairs(ctx.lists) do
		local v = fields["use_" .. i]
		if v ~= nil and (v == "true") ~= (sel[lname] == true) then
			sel[lname] = (v == "true") or nil
			changed = true
		end
	end
	for i, lname in ipairs(ctx.lists) do
		if fields["sel_" .. i] then
			sel[lname] = (not sel[lname]) or nil
			changed = true
		end
	end
	if changed then set_lists_set(meta, sel) end

	if fields.amount then
		local a = tonumber(fields.amount)
		if a and a ~= get_amount(meta) then meta:set_int("amount", a) end
	end
	if fields.filter_mode then
		meta:set_string("filter_mode", fields.filter_mode:find("except", 1, true) and "deny" or "allow")
	end

	show(pos, name)
	return true
end)

core.register_on_leaveplayer(function(player) contexts[player:get_player_name()] = nil end)

-- Nodes -----------------------------------------------------------------------------

local function register(kind, active)
	local k = KINDS[kind]
	local def = {
		description = "VaultNet " .. k.name .. (active and " (active)" or ""),
		drawtype = "mesh",
		mesh = "vaultnet_io_device.obj",
		tiles = {
			"vaultnet_io_" .. kind .. "_frame.png",
			active and {
				name = "vaultnet_io_" .. kind .. "_glow_active.png",
				animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.6},
			} or "vaultnet_io_" .. kind .. "_glow.png",
		},
		paramtype = "light",
		paramtype2 = "wallmounted",
		selection_box = BOX,
		collision_box = BOX,
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		groups = {cracky = 2, vaultnet_device = 1},
		drop = k.node,
		vaultnet = {
			role = kind,
			active_variant = not active and k.active or nil,
			inactive_variant = active and k.node or nil,
		},

		on_construct = function(pos)
			core.get_meta(pos):get_inventory():set_size("filter", FILTER_SLOTS)
		end,
		after_place_node = function(pos, placer)
			if placer then core.get_meta(pos):set_string("owner", placer:get_player_name()) end
		end,
		on_rightclick = function(pos, _, clicker)
			if not clicker or not clicker:is_player() then return end
			show(pos, clicker:get_player_name())
		end,

		-- filter slots are "ghosts": dropping an item records its name only
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if listname == "filter" and not core.is_protected(pos, player:get_player_name()) then
				local ghost = ItemStack(stack:get_name())
				core.get_meta(pos):get_inventory():set_stack("filter", index, ghost)
				show(pos, player:get_player_name())
			end
			return 0
		end,
		allow_metadata_inventory_take = function(pos, listname, index, _, player)
			if listname == "filter" and not core.is_protected(pos, player:get_player_name()) then
				core.get_meta(pos):get_inventory():set_stack("filter", index, ItemStack(""))
				show(pos, player:get_player_name())
			end
			return 0
		end,
		allow_metadata_inventory_move = function() return 0 end,
	}
	if active then
		def.light_source = 3
		def.groups.not_in_creative_inventory = 1
	end
	core.register_node(active and k.active or k.node, def)
end

for kind in pairs(KINDS) do
	register(kind, false)
	register(kind, true)
end
