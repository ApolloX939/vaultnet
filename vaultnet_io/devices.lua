-- Importer and Exporter.
--
--  Importer: target inventory -> network.   Exporter: network -> target inventory.
--
-- Place the device against a node: it points at that node. There is one node
-- per pointing direction (e.g. vaultnet_io:importer_ny points at the node below);
-- the placeable item picks the right one. Cable stubs are connected-nodebox arms,
-- so they only show on sides where a cable (or other device) is. Right-click
-- opens the configuration:
-- a non-interactive preview of the target's inventory layout where you click the
-- inventory lists to use, an amount per transfer and an item filter.
--
-- A device acts with its owner's rights on the core (put / pull) and respects
-- area protection on the target.

local A = vaultnet.access

local INTERVAL = tonumber(core.settings:get("vaultnet_io_interval")) or 1.0
local DEFAULT_AMOUNT = tonumber(core.settings:get("vaultnet_io_default_amount")) or 16
local AMOUNTS = {1, 2, 4, 8, 16, 32, 64}
local MAX_COUNT = 9999 -- largest per-item amount (Requester, Exporter)
local FILTER_SLOTS = 8
local FORMNAME = "vaultnet_io:device"

local KINDS = {
	importer = {name = "Importer", tint = "#d4ffe0"},
	exporter = {name = "Exporter", tint = "#ffe6c8"},
	-- Logistica-style, demand driven: a Requester keeps the target stocked with set
	-- amounts of items; a Supplier makes the target's items available to the network
	-- without moving them.
	requester = {name = "Requester", tint = "#cfe0ff"},
	supplier = {name = "Supplier", tint = "#e8d4ff"},
}

-- Pointing directions: suffix -> vector from the device to its target.
local DIRS = {
	ny = {x = 0, y = -1, z = 0}, py = {x = 0, y = 1, z = 0},
	nx = {x = -1, y = 0, z = 0}, px = {x = 1, y = 0, z = 0},
	nz = {x = 0, y = 0, z = -1}, pz = {x = 0, y = 0, z = 1},
}
local function suffix_of(v)
	for suffix, d in pairs(DIRS) do
		if d.x == v.x and d.y == v.y and d.z == v.z then return suffix end
	end
end

local function node_name(kind, suffix, active)
	return ("vaultnet_io:%s_%s%s"):format(kind, suffix, active and "_active" or "")
end

local kind_of = {}  -- node name -> kind
local dir_of = {}   -- node name -> direction vector to the target
for kind in pairs(KINDS) do
	for suffix, vec in pairs(DIRS) do
		for _, active in ipairs({false, true}) do
			local n = node_name(kind, suffix, active)
			kind_of[n], dir_of[n] = kind, vec
		end
	end
end

-- Shape, modelled on Refined Storage's Importer/Exporter: three stepped square
-- plates (half-widths in 1/16 node, 2 thick each) in front of a 4/16 core. The
-- Exporter's plates narrow towards the target, the Importer's widen. Written for
-- a target at -Y, then rotated per direction.
local PLATE_HALF = {
	exporter = {2, 3, 5},
	importer = {5, 3, 2},
	requester = {2, 3, 5},   -- pushes into the target like the Exporter
	supplier = {5, 3, 2},    -- opens the target to the network like the Importer
}
local R = 2 / 16 -- cable thickness, same as vaultnet_cables

-- Map a box from the "target at -Y" frame to direction `suffix`.
local function orient(box, suffix)
	local function pt(x, y, z)
		if suffix == "ny" then return x, y, z
		elseif suffix == "py" then return x, -y, z
		elseif suffix == "nx" then return y, x, z
		elseif suffix == "px" then return -y, x, z
		elseif suffix == "nz" then return x, z, y
		else return x, z, -y end -- pz
	end
	local ax, ay, az = pt(box[1], box[2], box[3])
	local bx, by, bz = pt(box[4], box[5], box[6])
	return {math.min(ax, bx), math.min(ay, by), math.min(az, bz),
		math.max(ax, bx), math.max(ay, by), math.max(az, bz)}
end

local function node_box(kind, suffix)
	local fixed = {}
	local y = -0.5
	for _, half in ipairs(PLATE_HALF[kind]) do
		local h = half / 16
		fixed[#fixed + 1] = orient({-h, y, -h, h, y + 2 / 16, h}, suffix)
		y = y + 2 / 16
	end
	fixed[#fixed + 1] = orient({-R, -R, -R, R, R, R}, suffix)

	local nb = {type = "connected", fixed = fixed}
	-- one cable stub per side, except the target side (the plates are there)
	local arms = {
		py = {"connect_top", {-R, R, -R, R, 0.5, R}},
		ny = {"connect_bottom", {-R, -0.5, -R, R, -R, R}},
		nz = {"connect_front", {-R, -R, -0.5, R, R, -R}},
		pz = {"connect_back", {-R, -R, R, R, R, 0.5}},
		nx = {"connect_left", {-0.5, -R, -R, -R, R, R}},
		px = {"connect_right", {R, -R, -R, 0.5, R, R}},
	}
	for side, arm in pairs(arms) do
		if side ~= suffix then nb[arm[1]] = arm[2] end
	end

	-- selectable/solid part: the plates and the core
	local sel = {}
	for i, b in ipairs(fixed) do sel[i] = b end
	return nb, {type = "fixed", fixed = sel}
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

-- Requester: amounts per filter slot ({[slot] = n}); default one stack
local function get_counts(meta)
	local s = meta:get_string("counts")
	return s ~= "" and core.deserialize(s) or {}
end

-- A slot that gets another item (or none) starts again from the default amount.
local function forget_count(meta, index)
	local counts = get_counts(meta)
	if counts[index] ~= nil then
		counts[index] = nil
		meta:set_string("counts", core.serialize(counts))
	end
end

-- An Importer or Exporter with items in an "only these" filter has an amount per filter slot.
local function uses_slot_amounts(meta)
	if meta:get_string("filter_mode") == "deny" then return false end
	local inv = meta:get_inventory()
	for i = 1, FILTER_SLOTS do
		if not inv:get_stack("filter", i):is_empty() then return true end
	end
	return false
end

local function target_pos(pos, node)
	local dir = dir_of[node.name]
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

-- Target inventory -> network with an amount per filter slot. Each slot moves its amount, or
-- whatever the target has when that is less (2 asked, 1 there: 1 moves). With `exact` a slot
-- moves only when the target holds its whole amount and the network has room for all of it.
local function do_import_counts(net, opts, tinv, lists, meta, default_amount, exact)
	local counts, inv = get_counts(meta), meta:get_inventory()
	local moved = 0
	for i = 1, FILTER_SLOTS do
		local ghost = inv:get_stack("filter", i)
		if not ghost:is_empty() then
			local name = ghost:get_name()
			local want = counts[i] or default_amount
			local available = 0
			for _, lname in ipairs(lists) do
				for _, st in ipairs(tinv:get_list(lname) or {}) do
					if st:get_name() == name then available = available + st:get_count() end
				end
			end
			local go = available > 0
			if go and exact then
				local used, cap = net:capacity()
				go = available >= want and cap - used >= want
			end
			if go and not vaultnet.drive.is_drive(ghost) then
				local left = want
				for _, lname in ipairs(lists) do
					for idx = 1, tinv:get_size(lname) do
						if left <= 0 then break end
						local st = tinv:get_stack(lname, idx)
						if st:get_name() == name then
							local part = st:take_item(math.min(left, st:get_count()))
							local leftover = net:insert(part, opts)
							local stored = part:get_count() - leftover:get_count()
							if not leftover:is_empty() then st:add_item(leftover) end
							tinv:set_stack(lname, idx, st)
							left = left - stored
							if not leftover:is_empty() then left = 0 end -- network full
						end
					end
				end
				moved = moved + (want - math.max(left, 0))
			end
		end
	end
	return moved
end

-- Items of `proto`'s kind the selected lists can still take.
local function room_for(tinv, lists, proto)
	local room, one = 0, ItemStack(proto:get_name())
	one:get_meta():from_table(proto:get_meta():to_table())
	for _, lname in ipairs(lists) do
		for _, s in ipairs(tinv:get_list(lname) or {}) do
			if s:is_empty() then
				room = room + proto:get_stack_max()
			elseif ItemStack(s):add_item(one):is_empty() then
				room = room + s:get_free_space()
			end
		end
	end
	return room
end

-- Move up to `budget` of the stored item `entry` into the target, a stack at a time, until the
-- budget is met, the network runs out or the target is full. Returns the number moved.
local function move_entry(net, opts, tinv, lists, entry, budget)
	local moved = 0
	local probe = vaultnet.key_to_stack(entry.key, 1)
	local remaining = entry.count
	while budget > 0 and remaining > 0 do
		-- stop when no selected list has room for this item
		local fits = false
		for _, lname in ipairs(lists) do
			if tinv:room_for_item(lname, probe) then fits = true break end
		end
		if not fits then break end
		local want = math.min(budget, remaining, probe:get_stack_max())
		local stack, err = net:extract_key(entry.key, want, opts)
		if err then break end
		local got = stack:get_count()
		if got == 0 then break end
		for _, lname in ipairs(lists) do
			if stack:is_empty() then break end
			stack = tinv:add_item(lname, stack)
		end
		local given = got - stack:get_count()
		if not stack:is_empty() then net:insert(stack) end -- put back what did not fit
		moved, budget, remaining = moved + given, budget - given, remaining - got
		if given < got then break end -- target full
	end
	return moved
end

-- Network -> target inventory: everything the filter allows, up to `budget` items in total.
local function do_export(net, opts, tinv, lists, allow, budget)
	local moved = 0
	for _, entry in ipairs(net:list()) do
		if budget <= 0 then break end
		if allow(entry.name) then
			local n = move_entry(net, opts, tinv, lists, entry, budget)
			moved, budget = moved + n, budget - n
		end
	end
	return moved
end

-- Network -> target inventory with an amount per filter slot. Each slot moves its amount, or
-- whatever is available and fits when that is less (2 asked, 1 there: 1 moves). With `exact`
-- a slot moves only when its whole amount is in the network and fits in the target.
local function do_export_counts(net, opts, tinv, lists, meta, default_amount, exact)
	local counts, inv = get_counts(meta), meta:get_inventory()
	local entries = net:list()
	local moved = 0
	for i = 1, FILTER_SLOTS do
		local ghost = inv:get_stack("filter", i)
		if not ghost:is_empty() then
			local name = ghost:get_name()
			local want = counts[i] or default_amount
			local mine, available = {}, 0
			for _, e in ipairs(entries) do
				if e.name == name then mine[#mine + 1] = e; available = available + e.count end
			end
			local go = available > 0
			if go and exact then
				go = available >= want
					and room_for(tinv, lists, vaultnet.key_to_stack(mine[1].key, 1)) >= want
			end
			if go then
				local left = want
				for _, e in ipairs(mine) do
					if left <= 0 then break end
					left = left - move_entry(net, opts, tinv, lists, e, left)
				end
				moved = moved + (want - left)
			end
		end
	end
	return moved
end

-- Network -> target inventory, only what is missing: keeps each filter item stocked up to
-- its amount (counted over the selected lists). Returns number of items moved.
local function do_request(net, opts, tinv, lists, meta, budget)
	local counts, inv = get_counts(meta), meta:get_inventory()
	local moved = 0
	for i = 1, FILTER_SLOTS do
		local ghost = inv:get_stack("filter", i)
		if budget > 0 and not ghost:is_empty() then
			local name = ghost:get_name()
			local want = counts[i] or ItemStack(name):get_stack_max()
			local have = 0
			for _, lname in ipairs(lists) do
				for _, s in ipairs(tinv:get_list(lname) or {}) do
					if s:get_name() == name then have = have + s:get_count() end
				end
			end
			local need = math.min(want - have, budget)
			local got = 0
			while got < need do
				local stack, err = net:extract_name(name, need - got, opts)
				if err or stack:is_empty() then break end
				local c0 = stack:get_count()
				for _, lname in ipairs(lists) do
					if stack:is_empty() then break end
					stack = tinv:add_item(lname, stack)
				end
				got = got + (c0 - stack:get_count())
				if not stack:is_empty() then net:insert(stack) break end -- target is full
			end
			moved, budget = moved + got, budget - got
		end
	end
	return moved
end

-- Supplier: the target's items (selected lists, filtered) as network slots.
local function supply_slots(pos)
	local node = core.get_node_or_nil(pos)
	if not node or not kind_of[node.name] then return {} end
	local tpos = target_pos(pos, node)
	if not core.get_node_or_nil(tpos) then return {} end
	local meta = core.get_meta(pos)
	local owner = meta:get_string("owner")
	if owner ~= "" and core.is_protected(tpos, owner) then return {} end
	local allow = make_filter(meta)
	local tinv = core.get_meta(tpos):get_inventory()
	local slots = {}
	for lname in pairs(get_lists_set(meta)) do
		for i = 1, tinv:get_size(lname) do
			local stack = tinv:get_stack(lname, i)
			if not stack:is_empty() and allow(stack:get_name()) and not vaultnet.drive.is_drive(stack) then
				slots[#slots + 1] = {
					get = function() return tinv:get_stack(lname, i) end,
					set = function(s) tinv:set_stack(lname, i, s) end,
				}
			end
		end
	end
	return slots
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
	if not vaultnet.is_powered(pos) then return set_info(pos, kind, "No power") end
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
	if kind == "importer" then
		if uses_slot_amounts(meta) then
			moved = do_import_counts(net, opts, tinv, lists, meta, budget, meta:get_int("exact") == 1)
		else
			moved = do_insert(net, opts, tinv, lists, allow, budget)
		end
	elseif kind == "exporter" then
		if uses_slot_amounts(meta) then
			moved = do_export_counts(net, opts, tinv, lists, meta, budget, meta:get_int("exact") == 1)
		else
			moved = do_export(net, opts, tinv, lists, allow, budget)
		end
		if moved > 0 then wake_target(tpos) end
	elseif kind == "requester" then
		moved = do_request(net, opts, tinv, lists, meta, budget)
		if moved > 0 then wake_target(tpos) end
	else -- supplier: items stay where they are
		return set_info(pos, kind, "Supplying " .. #supply_slots(pos) .. " stack(s)")
	end
	set_info(pos, kind, moved > 0 and "Working" or "Idle")
end

local ALL_NODES = {}
for name in pairs(kind_of) do ALL_NODES[#ALL_NODES + 1] = name end

core.register_abm({
	label = "VaultNet importer/exporter",
	nodenames = ALL_NODES,
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
		("label[0.5,1.0;%s]"):format(esc(({
			importer = "Takes from: %s (%d,%d,%d) into the network",
			exporter = "Puts into: %s (%d,%d,%d) from the network",
			requester = "Keeps stocked: %s (%d,%d,%d), taking what is missing from the network",
			supplier = "Offers to the network: %s (%d,%d,%d), items stay where they are",
		})[kind]:format(core.strip_colors(tdesc), tpos.x, tpos.y, tpos.z))),
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
	local aidx = 5
	for i, a in ipairs(AMOUNTS) do if a == amount then aidx = i end end
	if kind ~= "supplier" then
		fs[#fs + 1] = ((kind == "importer" or kind == "exporter") and "label[0.5,6.0;Items per transfer (no filter)]" or "label[0.5,6.0;Items per transfer]")
		fs[#fs + 1] = ("dropdown[0.5,6.2;2,0.7;amount;%s;%d]"):format(table.concat(AMOUNTS, ","), aidx)
	end
	local py = 8.9   -- player inventory
	local height = 13.4
	if kind == "requester" then
		fs[#fs + 1] = "label[0.5,7.2;Drop items on the slots to set what to keep stocked, and set the amount under each. Click a slot to clear it.]"
		local counts = get_counts(meta)
		local inv = meta:get_inventory()
		for i = 1, FILTER_SLOTS do
			local g = inv:get_stack("filter", i)
			local x = 0.5 + (i - 1) * 1.25
			if not g:is_empty() then
				fs[#fs + 1] = ("field[%f,8.7;1,0.5;count_%d;;%d]"):format(x, i, counts[i] or g:get_stack_max())
			end
		end
		fs[#fs + 1] = "field_close_on_enter[count_1;false]"
		py, height = 9.6, 14.1
	else
		fs[#fs + 1] = "label[3.0,6.0;Filter]"
		fs[#fs + 1] = ("dropdown[3.0,6.2;3.4,0.7;filter_mode;Only these items,Everything except these;%d]"):format(
			meta:get_string("filter_mode") == "deny" and 2 or 1)
		if (kind == "exporter" or kind == "importer") and uses_slot_amounts(meta) then
			-- an amount per filter slot, and whether it must be met in full
			fs[#fs + 1] = ("checkbox[6.7,6.55;exact;Exact amounts;%s]"):format(meta:get_int("exact") == 1 and "true" or "false")
			fs[#fs + 1] = "tooltip[exact;Off: moves the amount, or what is there if less (2 asked, 1 there: 1 moves).\nOn: moves nothing unless the whole amount is available and fits.]"
			fs[#fs + 1] = "label[0.5,7.2;Drop items on the slots and set the amount to move under each. Click a slot to clear it.]"
			local counts = get_counts(meta)
			local inv = meta:get_inventory()
			for i = 1, FILTER_SLOTS do
				if not inv:get_stack("filter", i):is_empty() then
					fs[#fs + 1] = ("field[%f,8.7;1,0.5;count_%d;;%d]"):format(0.5 + (i - 1) * 1.25, i, counts[i] or amount)
					fs[#fs + 1] = ("field_close_on_enter[count_%d;false]"):format(i)
				end
			end
			py, height = 9.6, 14.1
		else
			fs[#fs + 1] = "label[0.5,7.2;Drop items on the slots to set the filter (empty = everything). Click a slot to clear it.]"
		end
	end
	fs[#fs + 1] = ("list[context;filter;0.5,7.4;%d,1;]"):format(FILTER_SLOTS)
	fs[#fs + 1] = ("list[current_player;main;0.5,%f;8,4;]"):format(py)
	fs[#fs + 1] = ("listring[nodemeta:%d,%d,%d;filter]listring[current_player;main]"):format(pos.x, pos.y, pos.z)
	fs[1] = ("formspec_version[4]size[12,%f]"):format(height)
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
	if fields.exact ~= nil and (kind_of[node.name] == "exporter" or kind_of[node.name] == "importer") then
		meta:set_int("exact", fields.exact == "true" and 1 or 0)
	end
	if kind_of[node.name] ~= "supplier" then
		local counts = get_counts(meta)
		local edited = false
		for i = 1, FILTER_SLOTS do
			local v = tonumber(fields["count_" .. i])
			if v then
				v = math.max(1, math.min(MAX_COUNT, math.floor(v)))
				if counts[i] ~= v then counts[i] = v; edited = true end
			end
		end
		if edited then meta:set_string("counts", core.serialize(counts)) end
	end
	if fields.filter_mode then
		meta:set_string("filter_mode", fields.filter_mode:find("except", 1, true) and "deny" or "allow")
	end

	show(pos, name)
	return true
end)

core.register_on_leaveplayer(function(player) contexts[player:get_player_name()] = nil end)

-- Nodes -----------------------------------------------------------------------------

local function register(kind, suffix, active)
	local k = KINDS[kind]
	local item = "vaultnet_io:" .. kind
	local nb, sel = node_box(kind, suffix)
	-- cable looks (animated while active), lightly tinted per device kind
	local tint = "^[multiply:" .. k.tint
	local texture = active and {
		name = "vaultnet_cables_cable_active.png" .. tint,
		animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 2.0},
	} or ("vaultnet_cables_cable.png" .. tint)
	local def = {
		description = "VaultNet " .. k.name .. (active and " (active)" or ""),
		drawtype = "nodebox",
		node_box = nb,
		selection_box = sel,
		collision_box = sel,
		connects_to = {"group:vaultnet_device"},
		tiles = {texture},
		paramtype = "light",
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		groups = {cracky = 2, vaultnet_device = 1, not_in_creative_inventory = 1},
		drop = item,
		vaultnet = {
			role = kind,
			consumes_power = true,
			get_supply = kind == "supplier" and supply_slots or nil,
			active_variant = not active and node_name(kind, suffix, true) or nil,
			inactive_variant = active and node_name(kind, suffix, false) or nil,
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
				local meta = core.get_meta(pos)
				meta:get_inventory():set_stack("filter", index, ghost)
				forget_count(meta, index)
				show(pos, player:get_player_name())
			end
			return 0
		end,
		allow_metadata_inventory_take = function(pos, listname, index, _, player)
			if listname == "filter" and not core.is_protected(pos, player:get_player_name()) then
				local meta = core.get_meta(pos)
				meta:get_inventory():set_stack("filter", index, ItemStack(""))
				forget_count(meta, index)
				show(pos, player:get_player_name())
			end
			return 0
		end,
		allow_metadata_inventory_move = function() return 0 end,
	}
	if active then def.light_source = 3 end
	core.register_node(node_name(kind, suffix, active), def)
end

-- The item you hold: places the variant that points at the clicked node.
local function register_item(kind)
	local k = KINDS[kind]
	core.register_craftitem("vaultnet_io:" .. kind, {
		description = "VaultNet " .. k.name,
		inventory_image = "vaultnet_io_" .. kind .. ".png",
		wield_image = "vaultnet_io_" .. kind .. ".png",
		on_place = function(itemstack, placer, pointed)
			if not placer or not pointed or pointed.type ~= "node" then return itemstack end
			local toward = vector.subtract(pointed.under, pointed.above)
			local suffix = suffix_of(toward)
			if not suffix then return itemstack end
			local left = core.item_place(ItemStack(node_name(kind, suffix, false)), placer, pointed)
			if left and left:is_empty() and not core.is_creative_enabled(placer:get_player_name()) then
				itemstack:take_item()
			end
			return itemstack
		end,
	})
end

for kind in pairs(KINDS) do
	register_item(kind)
	for suffix in pairs(DIRS) do
		register(kind, suffix, false)
		register(kind, suffix, true)
	end
end

-- The Inserter was renamed Importer. Aliases turn every old Inserter (items in inventories
-- and chests, nodes already placed in the world, with their settings and filter) into the
-- matching Importer, so there is nothing to swap by hand.
core.register_alias("vaultnet_io:inserter", "vaultnet_io:importer")
for suffix in pairs(DIRS) do
	core.register_alias(node_name("inserter", suffix, false), node_name("importer", suffix, false))
	core.register_alias(node_name("inserter", suffix, true), node_name("importer", suffix, true))
end
