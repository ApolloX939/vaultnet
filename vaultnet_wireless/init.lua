-- Wireless relay. Relays with the same name form one network link, over any
-- distance (optionally capped by a range setting). The other end needs no core:
-- the linked networks simply become one. Names:
--   base          public: any relay called "base" links, whoever placed it
--   apollo:base   private: only apollo can give a relay that name
-- Linked relays forceload their map blocks so the link keeps working while nobody
-- is near (transient forceloads, re-applied on every start from the name index).

if core.settings:get_bool("vaultnet_wireless_enabled", true) == false then
	core.log("action", "[vaultnet_wireless] disabled by setting")
	return
end

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/registry.lua")
local R = vaultnet.wireless

local IDLE, ACTIVE = "vaultnet_wireless:relay", "vaultnet_wireless:relay_active"
local FORMNAME = "vaultnet_wireless:relay"

local function px(a, b, c, d, e, f)
	return {a / 16, b / 16, c / 16, d / 16, e / 16, f / 16}
end

local SEL = px(-4, -4, -4, 4, 8, 4)

local function node_box()
	return {
		type = "connected",
		fixed = {
			px(-4, -4, -4, 4, 2, 4),            -- body
			px(-1, 2, -1, 1, 7, 1),             -- mast
			px(-3.5, 5, -0.5, 3.5, 6, 0.5),     -- crossbar
			px(-0.5, 5, -3.5, 0.5, 6, 3.5),
			px(-1.5, 7, -1.5, 1.5, 8, 1.5),     -- ball
		},
		-- cable stubs (4px, like the cables) only where something is connected
		connect_top = {px(-2, 2, -2, 2, 8, 2)},
		connect_bottom = {px(-2, -8, -2, 2, -4, 2)},
		connect_front = {px(-2, -2, -8, 2, 2, -4)},
		connect_back = {px(-2, -2, 4, 2, 2, 8)},
		connect_left = {px(-8, -2, -2, -4, 2, 2)},
		connect_right = {px(4, -2, -2, 8, 2, 2)},
	}
end

-- Linking -------------------------------------------------------------------------

local function is_relay(name) return name == IDLE or name == ACTIVE end

vaultnet.register_link_provider(function(pos, _, def)
	if def.role ~= "relay" then return nil end
	-- The link does not depend on power: whether a relay is powered is decided by the
	-- network it belongs to, and asking for that network while building it would never
	-- end. An unpowered combined network is unpowered at both ends anyway.
	local partners = R.partners(pos)
	local out, stale = {}, {}
	for _, p in ipairs(partners) do
		local n = core.get_node_or_nil(p)
		if n and not is_relay(n.name) then
			stale[#stale + 1] = p       -- the relay at that position is gone
		else
			out[#out + 1] = p           -- (an unloaded partner just leaves the scan incomplete)
		end
	end
	if #stale > 0 then
		core.after(0, function()
			for _, p in ipairs(stale) do
				local n = core.get_node_or_nil(p)
				if n and not is_relay(n.name) then R.remove(p) end
			end
		end)
	end
	return out
end)

local function describe(pos)
	local meta = core.get_meta(pos)
	local name = meta:get_string("relay_name")
	if not vaultnet.is_powered(pos) then return "VaultNet Wireless Relay\nNo power" end
	if name == "" then return "VaultNet Wireless Relay\nNot named yet (right-click)" end
	local partners = R.partners(pos)
	local loaded = 0
	for _, p in ipairs(partners) do
		if core.get_node_or_nil(p) then loaded = loaded + 1 end
	end
	local line
	if #partners == 0 then
		line = "No other relay with this name"
	elseif loaded < #partners then
		line = ("Linked to %d relay(s), %d not loaded"):format(#partners, #partners - loaded)
	else
		line = ("Linked to %d relay(s)"):format(#partners)
	end
	return ("VaultNet Wireless Relay\n%s\n%s"):format(name, line)
end

local function refresh_info(pos)
	local meta = core.get_meta(pos)
	local text = describe(pos)
	if meta:get_string("infotext") ~= text then meta:set_string("infotext", text) end
end

-- Make the registry agree with the node meta (placed by WorldEdit, restored from
-- storage, area just loaded, ...).
local function heal(pos)
	local node = core.get_node_or_nil(pos)
	if not node or not is_relay(node.name) then return end
	local meta = core.get_meta(pos)
	local name = meta:get_string("relay_name")
	if name ~= "" and R.name_at(pos) ~= name then
		local ok = R.check_name(name, meta:get_string("owner"))
		if ok then
			R.add(name, pos)
		else
			meta:set_string("infotext", "VaultNet Wireless Relay\nInvalid private name")
			return
		end
	elseif name == "" and R.name_at(pos) then
		R.remove(pos)
	end
	refresh_info(pos)
end

-- Formspec ------------------------------------------------------------------------

local contexts = {}

local function build(pos)
	local meta = core.get_meta(pos)
	local esc = core.formspec_escape
	local partners = R.partners(pos)
	local fs = {
		"formspec_version[4]size[9,7.4]",
		"label[0.5,0.5;VaultNet Wireless Relay]",
		("label[0.5,1.0;Placed by: %s]"):format(esc(meta:get_string("owner"))),
		("field[0.5,1.8;5.6,0.7;relay_name;Relay name;%s]"):format(esc(meta:get_string("relay_name"))),
		"field_close_on_enter[relay_name;false]",
		"button[6.3,1.8;2.2,0.7;set;Set]",
		"label[0.5,3.0;Relays with the same name link their networks, at any distance.]",
		"label[0.5,3.4;A plain name is public: anyone can join it by typing it.]",
		"label[0.5,3.8;player:name is private: only that player can use it.]",
		("label[0.5,4.5;%s]"):format(esc((describe(pos):gsub("^[^\n]*\n[^\n]*\n?", "")))),
	}
	if #partners > 0 then
		local lines = {}
		for i, p in ipairs(partners) do
			if i > 5 then lines[#lines + 1] = "..." break end
			lines[#lines + 1] = ("%d,%d,%d"):format(p.x, p.y, p.z)
		end
		fs[#fs + 1] = ("label[0.5,5.0;Other relays: %s]"):format(esc(table.concat(lines, "   ")))
	end
	if R.forceload_failed(pos) then
		fs[#fs + 1] = "label[0.5,5.6;Could not forceload this block (server forceload limit).]"
	elseif R.is_forceloaded(pos) then
		fs[#fs + 1] = "label[0.5,5.6;This relay is forceloaded.]"
	end
	return table.concat(fs)
end

local function show(pos, name)
	contexts[name] = vector.copy(pos)
	core.show_formspec(name, FORMNAME, build(pos))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then return end
	local pname = player:get_player_name()
	local pos = contexts[pname]
	if fields.quit then
		contexts[pname] = nil
		return true
	end
	if not pos then return true end
	local node = core.get_node_or_nil(pos)
	if not node or not is_relay(node.name) then return true end

	if (fields.set or fields.key_enter_field == "relay_name") and fields.relay_name then
		if core.is_protected(pos, pname) then
			core.record_protection_violation(pos, pname)
			return true
		end
		local ok, result = R.check_name(fields.relay_name, pname)
		if not ok then
			core.chat_send_player(pname, "[VaultNet] " .. result)
		else
			local meta = core.get_meta(pos)
			meta:set_string("relay_name", result)
			if result == "" then R.remove(pos) else R.add(result, pos) end
			refresh_info(pos)
		end
		show(pos, pname)
	end
	return true
end)

core.register_on_leaveplayer(function(player) contexts[player:get_player_name()] = nil end)

-- Nodes -----------------------------------------------------------------------------

local function register(name, desc, tile, vn, extra)
	local def = {
		description = desc,
		drawtype = "nodebox",
		node_box = node_box(),
		selection_box = {type = "fixed", fixed = SEL},
		collision_box = {type = "fixed", fixed = SEL},
		connects_to = {"group:vaultnet_device"},
		tiles = {tile},
		inventory_image = "vaultnet_wireless_icon.png",
		wield_image = "vaultnet_wireless_icon.png",
		paramtype = "light",
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		groups = vaultnet.groups({vaultnet_device = 1}),
		vaultnet = vn,

		after_place_node = function(pos, placer)
			local meta = core.get_meta(pos)
			if placer then meta:set_string("owner", placer:get_player_name()) end
			refresh_info(pos)
		end,
		on_destruct = function(pos) R.remove(pos) end,
		on_rightclick = function(pos, _, clicker)
			if clicker and clicker:is_player() then show(pos, clicker:get_player_name()) end
		end,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_node(name, def)
end

register(IDLE, "VaultNet Wireless Relay", "vaultnet_wireless_relay.png", {
	role = "relay",
	consumes_power = true,
	active_variant = ACTIVE,
})

register(ACTIVE, "VaultNet Wireless Relay (active)", {
	name = "vaultnet_wireless_relay_active.png",
	animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.6},
}, {
	role = "relay",
	consumes_power = true,
	inactive_variant = IDLE,
}, {
	drop = IDLE,
	light_source = 4,
	groups = vaultnet.groups({vaultnet_device = 1, not_in_creative_inventory = 1}),
})

core.register_lbm({
	name = "vaultnet_wireless:restore_relays",
	nodenames = {IDLE, ACTIVE},
	run_at_every_load = true,
	action = heal,
})

core.register_abm({
	label = "VaultNet relay upkeep",
	nodenames = {IDLE, ACTIVE},
	interval = 5,
	chance = 1,
	action = heal,
})

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
