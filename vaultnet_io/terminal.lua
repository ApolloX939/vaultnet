-- Terminal: browse the network's contents, take items out, put items in.
--
--  * Insert: drop items into the "Insert" slots; they go into the network at
--    once (anything that does not fit stays in the slot).
--  * Take: click an item; the amount comes from the dropdown (1 / 10 / Stack).
--  * Needs "put" or "pull" access on the core to open; each action checks its
--    own permission.

local A = vaultnet.access

local IDLE, ACTIVE = "vaultnet_io:terminal", "vaultnet_io:terminal_active"
local INPUT_SLOTS = 4
local COLS, ROWS = 8, 3
local PER_PAGE = COLS * ROWS
local FORMNAME = "vaultnet_io:terminal"
local AMOUNTS = {"1", "10", "Stack"}

local contexts = {} -- player -> {pos, entries, search, page, amount}

local ERR_TEXT = {
	no_core = "This network has no core.",
	multiple_cores = "This network has more than one core.",
	unpowered = "The network has no power.",
	denied = "You do not have access to do that.",
	not_storable = "That can not be stored.",
}

local function say(name, msg)
	core.chat_send_player(name, "[VaultNet] " .. msg)
end

-- Helpers ---------------------------------------------------------------------

local function short_count(n)
	if n < 1000 then return tostring(n) end
	if n < 1000000 then return ("%.1fk"):format(n / 1000) end
	return ("%.1fM"):format(n / 1000000)
end

local function describe(key)
	local s = vaultnet.key_to_stack(key, 1)
	local d = s.get_description and s:get_description() or ""
	if d == "" then d = s:get_name() end
	return d
end

local function plain(s)
	return (core.strip_colors(s):gsub("\n.*", "")):lower()
end

-- Network + core for the terminal at pos: net, core_pos | nil, status
local function net_of(pos)
	local net = vaultnet.get_network(pos)
	if not net then return nil, nil, "no_core" end
	local status = net:status()
	if status == "ok" and not vaultnet.is_powered(pos) then status = "unpowered" end
	return net, net:get_core(), status
end

local function filter(entries, search)
	if search == "" then return entries end
	local needle = search:lower()
	local out = {}
	for _, e in ipairs(entries) do
		if e.name:lower():find(needle, 1, true)
				or plain(describe(e.key)):find(needle, 1, true) then
			out[#out + 1] = e
		end
	end
	return out
end

-- Formspec --------------------------------------------------------------------

local function build(pos, name)
	local ctx = contexts[name]
	local net, core_pos, status = net_of(pos)
	local esc = core.formspec_escape
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z

	local fs = {"formspec_version[4]size[11,12.4]", "label[0.5,0.5;VaultNet Terminal]"}

	local allowed = core_pos and (A.can(core_pos, name, "put") or A.can(core_pos, name, "pull"))
	if status ~= "ok" or not allowed then
		ctx.entries = {}
		fs[#fs + 1] = ("label[0.5,1.5;%s]"):format(esc(
			status ~= "ok" and (ERR_TEXT[status] or status)
			or "You do not have access to this network."))
		fs[#fs + 1] = "list[current_player;main;0.5,7.3;8,4;]"
		return table.concat(fs)
	end

	local entries = filter(net:list(), ctx.search)
	ctx.entries = entries
	local pages = math.max(1, math.ceil(#entries / PER_PAGE))
	ctx.page = math.min(math.max(ctx.page, 1), pages)

	local used, cap = net:capacity()
	fs[#fs + 1] = ("label[5.5,0.5;Storage: %s / %s (%s)]"):format(short_count(used), short_count(cap),
		vaultnet.format_percent(used, cap))

	-- controls
	local amount_idx = 3
	for i, a in ipairs(AMOUNTS) do if a == ctx.amount then amount_idx = i end end
	fs[#fs + 1] = ("field[0.5,0.9;3.2,0.7;search;;%s]"):format(esc(ctx.search))
	fs[#fs + 1] = "field_close_on_enter[search;false]"
	fs[#fs + 1] = "button[3.8,0.9;1.4,0.7;dosearch;Search]"
	fs[#fs + 1] = ("dropdown[5.4,0.9;1.6,0.7;amount;%s;%d]"):format(table.concat(AMOUNTS, ","), amount_idx)
	fs[#fs + 1] = "button[7.2,0.9;0.8,0.7;prev;<]"
	fs[#fs + 1] = ("label[8.15,1.25;%d/%d]"):format(ctx.page, pages)
	fs[#fs + 1] = "button[9.0,0.9;0.8,0.7;next;>]"

	-- item grid
	local first = (ctx.page - 1) * PER_PAGE
	for slot = 0, PER_PAGE - 1 do
		local e = entries[first + slot + 1]
		local x, y = 0.5 + (slot % COLS) * 1.25, 1.9 + math.floor(slot / COLS) * 1.25
		if e then
			local fname = "item_" .. (first + slot + 1)
			fs[#fs + 1] = ("item_image_button[%f,%f;1,1;%s;%s;%s]"):format(
				x, y, esc(e.name), fname, esc(short_count(e.count)))
			fs[#fs + 1] = ("tooltip[%s;%s]"):format(fname,
				esc(("%s\n%d stored"):format(describe(e.key), e.count)))
		else
			fs[#fs + 1] = ("box[%f,%f;1,1;#00000040]"):format(x, y)
		end
	end

	-- insert slots + player inventory
	fs[#fs + 1] = "label[0.5,6.35;Insert:]"
	fs[#fs + 1] = ("list[nodemeta:%s;input;1.9,5.85;%d,1;]"):format(spos, INPUT_SLOTS)
	fs[#fs + 1] = "list[current_player;main;0.5,7.3;8,4;]"
	fs[#fs + 1] = ("listring[nodemeta:%s;input]listring[current_player;main]"):format(spos)
	return table.concat(fs)
end

local function show(pos, name)
	core.show_formspec(name, FORMNAME, build(pos, name))
end

-- Actions ---------------------------------------------------------------------

local function give(player, stack, net)
	local inv = player:get_inventory()
	local left = inv:add_item("main", stack)
	if not left:is_empty() and net then left = net:insert(left) end -- put back
	if not left:is_empty() then
		core.item_drop(left, player, player:get_pos())
	end
end

local function take(pos, player, entry, amount_label)
	local name = player:get_player_name()
	local net, _, status = net_of(pos)
	if not net then return end
	if status ~= "ok" then say(name, ERR_TEXT[status] or status) return end
	local want
	if amount_label == "1" then
		want = 1
	elseif amount_label == "10" then
		want = 10
	else
		want = vaultnet.key_stack_max(entry.key)
	end
	local stack, err = net:extract_key(entry.key, want, {actor = name})
	if err then say(name, ERR_TEXT[err] or err) return end
	if not stack:is_empty() then give(player, stack, net) end
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
	local node = core.get_node_or_nil(ctx.pos)
	if not node or (node.name ~= IDLE and node.name ~= ACTIVE) then return true end

	if fields.amount then ctx.amount = fields.amount end
	if fields.search ~= nil and fields.search ~= ctx.search then
		ctx.search = fields.search
		ctx.page = 1
	end
	if fields.prev then ctx.page = ctx.page - 1 end
	if fields.next then ctx.page = ctx.page + 1 end

	for i, entry in ipairs(ctx.entries) do
		if fields["item_" .. i] then
			take(ctx.pos, player, entry, ctx.amount)
			break
		end
	end

	show(ctx.pos, name)
	return true
end)

core.register_on_leaveplayer(function(player) contexts[player:get_player_name()] = nil end)

-- Node ------------------------------------------------------------------------

local function register(name, desc, front, vn, extra)
	local side = "vaultnet_io_terminal_side.png"
	local def = {
		description = desc,
		paramtype2 = "4dir",
		tiles = {side, side, side, side, side, front},
		groups = {cracky = 2, vaultnet_device = 1},
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		vaultnet = vn,

		on_construct = function(pos)
			core.get_meta(pos):get_inventory():set_size("input", INPUT_SLOTS)
		end,
		on_rightclick = function(pos, _, clicker)
			if not clicker or not clicker:is_player() then return end
			local pname = clicker:get_player_name()
			contexts[pname] = {pos = vector.copy(pos), entries = {}, search = "",
				page = 1, amount = "Stack"}
			show(pos, pname)
		end,
		can_dig = function(pos)
			return core.get_meta(pos):get_inventory():is_empty("input")
		end,

		allow_metadata_inventory_put = function(pos, _, _, stack, player)
			local pname = player:get_player_name()
			if core.is_protected(pos, pname) then
				core.record_protection_violation(pos, pname)
				return 0
			end
			if vaultnet.drive.is_drive(stack) then
				say(pname, ERR_TEXT.not_storable)
				return 0
			end
			local net, _, status = net_of(pos)
			local ok, err = false, status
			if net and status == "ok" then ok, err = net:check({actor = pname}, "put") end
			if not ok then
				say(pname, ERR_TEXT[err] or err)
				return 0
			end
			return stack:get_count()
		end,
		allow_metadata_inventory_move = function() return 0 end,
		allow_metadata_inventory_take = function(pos, _, _, stack, player)
			local pname = player:get_player_name()
			if core.is_protected(pos, pname) then return 0 end
			return stack:get_count()
		end,
		on_metadata_inventory_put = function(pos, listname, index, _, player)
			local pname = player:get_player_name()
			local inv = core.get_meta(pos):get_inventory()
			local net = net_of(pos)
			if not net then return end
			local leftover, err = net:insert(inv:get_stack(listname, index), {actor = pname})
			inv:set_stack(listname, index, leftover)
			if not leftover:is_empty() then
				say(pname, err and (ERR_TEXT[err] or err) or "The network is full.")
			end
			if contexts[pname] then show(pos, pname) end
		end,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_node(name, def)
end

register(IDLE, "VaultNet Terminal", "vaultnet_io_terminal_front.png", {
	role = "terminal",
	consumes_power = true,
	active_variant = ACTIVE,
})

register(ACTIVE, "VaultNet Terminal (active)", {
	name = "vaultnet_io_terminal_front_active.png",
	animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 4.8},
}, {
	role = "terminal",
	consumes_power = true,
	inactive_variant = IDLE,
}, {
	drop = IDLE,
	light_source = 4,
	groups = {cracky = 2, vaultnet_device = 1, not_in_creative_inventory = 1},
})
