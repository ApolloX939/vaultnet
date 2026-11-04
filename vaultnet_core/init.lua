local modpath = core.get_modpath(core.get_current_modname())
local A = vaultnet.access

local IDLE, ACTIVE, CONFLICT =
	"vaultnet_core:core", "vaultnet_core:core_active", "vaultnet_core:core_conflict"

local FULL = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}

local STATUS_TEXT = {
	ok = "Online",
	no_core = "No core",
	multiple_cores = "CONFLICT: more than one core on this network",
	unpowered = "No power",
}

local function animated(texture, length)
	return {
		name = texture,
		animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = length},
	}
end

local show_formspec -- defined below

-- Crystal (entity) ---------------------------------------------------------------
-- A floating d12 in the middle of the cage. Entities are not saved: the crystal
-- is recreated from the node (LBM, status ABM, and when the variant is swapped).

local CRYSTAL = "vaultnet_core:crystal"
local FRAMES = 8
local STATE_OF = {[IDLE] = "idle", [ACTIVE] = "active", [CONFLICT] = "conflict"}
local LOOK = { -- glow, spin (rad/s), animated?
	idle = {glow = 4, spin = 0.3, animated = false},
	active = {glow = 14, spin = 0.8, animated = true},
	conflict = {glow = 14, spin = 3.0, animated = true},
}

local function crystal_texture(state, frame)
	local base = "vaultnet_core_crystal_" .. state .. ".png"
	if not LOOK[state].animated then return base end
	return base .. "^[verticalframe:" .. FRAMES .. ":" .. frame
end

core.register_entity(CRYSTAL, {
	initial_properties = {
		visual = "mesh",
		mesh = "vaultnet_core_crystal.obj",
		-- entity meshes render at 1/10 of the model size
		visual_size = {x = 10, y = 10, z = 10},
		textures = {"vaultnet_core_crystal_idle.png"},
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		glow = 4,
		automatic_rotate = 0.3,
	},
	on_step = function(self, dtime)
		-- Remove ourselves when the core is gone or moved, so no stray crystals
		-- linger at an old position.
		self.check_timer = (self.check_timer or 0) + dtime
		if self.check_timer >= 2 then
			self.check_timer = 0
			if not self.core_pos then return self.object:remove() end
			local node = core.get_node_or_nil(self.core_pos)
			if node and not STATE_OF[node.name] then return self.object:remove() end
		end
		if not self.state or not LOOK[self.state].animated then return end
		self.timer = (self.timer or 0) + dtime
		if self.timer < 0.25 then return end
		self.timer = 0
		self.frame = ((self.frame or 0) + 1) % FRAMES
		self.object:set_properties({textures = {crystal_texture(self.state, self.frame)}})
	end,
})

local function find_crystal(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.6)) do
		local e = obj:get_luaentity()
		if e and e.name == CRYSTAL and e.core_pos and vector.equals(e.core_pos, pos) then
			return obj, e
		end
	end
end

local function remove_crystal(pos)
	local obj = find_crystal(pos)
	if obj then obj:remove() end
end

local function update_crystal(pos)
	local node = core.get_node_or_nil(pos)
	local state = node and STATE_OF[node.name]
	if not state then return end
	local obj, e = find_crystal(pos)
	if not obj then
		obj = core.add_entity(pos, CRYSTAL)
		if not obj then return end
		e = obj:get_luaentity()
		e.core_pos = vector.copy(pos)
	end
	if e.state ~= state then
		e.state, e.frame, e.timer = state, 0, 0
		local look = LOOK[state]
		obj:set_properties({
			textures = {crystal_texture(state, 0)},
			glow = look.glow,
			automatic_rotate = look.spin,
		})
	end
end

-- Nodes -----------------------------------------------------------------------
-- The housing is a metal cage (corner blocks and edge bars, open faces) around the
-- crystal. Like the cables it is a connected nodebox: a short plug with a collar
-- appears on each side that has a cable (or other device), so you can see what is
-- attached to it.

local function px(a, b, c, d, e, f)
	return {a / 16, b / 16, c / 16, d / 16, e / 16, f / 16}
end

local function cage()
	local boxes = {}
	for _, sx in ipairs({-1, 1}) do
		for _, sy in ipairs({-1, 1}) do
			for _, sz in ipairs({-1, 1}) do
				local function r(s) return s < 0 and -8 or 5, s < 0 and -5 or 8 end
				local x0, x1 = r(sx)
				local y0, y1 = r(sy)
				local z0, z1 = r(sz)
				boxes[#boxes + 1] = px(x0, y0, z0, x1, y1, z1) -- corner block 3px
			end
		end
	end
	-- edge bars, 2px thick, between the corner blocks
	for _, a in ipairs({-1, 1}) do
		for _, b in ipairs({-1, 1}) do
			local function band(s) return s < 0 and -8 or 6, s < 0 and -6 or 8 end
			local a0, a1 = band(a)
			local b0, b1 = band(b)
			boxes[#boxes + 1] = px(-5, a0, b0, 5, a1, b1)   -- along x
			boxes[#boxes + 1] = px(a0, -5, b0, a1, 5, b1)   -- along y
			boxes[#boxes + 1] = px(a0, b0, -5, a1, b1, 5)   -- along z
		end
	end
	return boxes
end

local function node_box()
	-- plug: a 4px stub from the face in to 4px from the centre, with a 6px collar
	local nb = {
		type = "connected",
		fixed = cage(),
		connect_top = {px(-2, 4, -2, 2, 8, 2), px(-3, 4, -3, 3, 5, 3)},
		connect_bottom = {px(-2, -8, -2, 2, -4, 2), px(-3, -5, -3, 3, -4, 3)},
		connect_front = {px(-2, -2, -8, 2, 2, -4), px(-3, -3, -5, 3, 3, -4)},
		connect_back = {px(-2, -2, 4, 2, 2, 8), px(-3, -3, 4, 3, 3, 5)},
		connect_left = {px(-8, -2, -2, -4, 2, 2), px(-5, -3, -3, -4, 3, 3)},
		connect_right = {px(4, -2, -2, 8, 2, 2), px(4, -3, -3, 5, 3, 3)},
	}
	return nb
end

local function register(name, desc, tile, extra)
	local def = {
		description = desc,
		drawtype = "nodebox",
		node_box = node_box(),
		selection_box = FULL,
		collision_box = FULL,
		connects_to = {"group:vaultnet_device"},
		tiles = {tile},
		inventory_image = "vaultnet_core_icon.png",
		wield_image = "vaultnet_core_icon.png",
		paramtype = "light",
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		groups = {cracky = 2, vaultnet_device = 1, vaultnet_core = 1},
		vaultnet = {
			role = "core",
			consumes_power = true,
			active_variant = ACTIVE,
			inactive_variant = IDLE,
			-- two cores on one network: both turn red
			variants = {multiple_cores = CONFLICT},
			on_swapped = function(pos) update_crystal(pos) end,
		},

		after_place_node = function(pos, placer)
			local pname = placer and placer:get_player_name() or ""
			A.init(pos, pname)
			update_crystal(pos)
			local net = vaultnet.get_network(pos)
			if net and #net.cores > 1 and pname ~= "" then
				core.chat_send_player(pname, "[VaultNet] This network already has a core. " ..
					"Both cores show a conflict until one of them is removed.")
			end
		end,
		on_destruct = remove_crystal,
		can_dig = function(pos, player)
			return player ~= nil and A.can(pos, player:get_player_name(), "admin")
		end,
		on_rightclick = function(pos, _, clicker)
			if clicker and clicker:is_player() then
				show_formspec(pos, clicker:get_player_name())
			end
		end,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_node(name, def)
end

register(IDLE, "VaultNet Core", "vaultnet_core_housing.png")

register(ACTIVE, "VaultNet Core (active)",
	animated("vaultnet_core_housing_active.png", 1.6), {
	drop = IDLE,
	light_source = 8,
	groups = {cracky = 2, vaultnet_device = 1, vaultnet_core = 1, not_in_creative_inventory = 1},
})

register(CONFLICT, "VaultNet Core (conflict)",
	animated("vaultnet_core_housing_conflict.png", 0.8), {
	drop = IDLE,
	light_source = 8,
	groups = {cracky = 2, vaultnet_device = 1, vaultnet_core = 1, not_in_creative_inventory = 1},
})

core.register_lbm({
	name = "vaultnet_core:restore_crystals",
	nodenames = {IDLE, ACTIVE, CONFLICT},
	run_at_every_load = true,
	action = update_crystal,
})

-- Status upkeep ---------------------------------------------------------------
-- Topology changes already refresh the looks (vaultnet_api visuals); this also
-- catches state that is not a topology change (power) and keeps the infotext
-- current. One update per network per game second.

core.register_abm({
	label = "VaultNet core status",
	nodenames = {"group:vaultnet_core"},
	interval = 2,
	chance = 1,
	action = function(pos)
		local net = vaultnet.get_network(pos)
		if not net then return end
		local status = net:status()
		local now = core.get_gametime()
		if net.status_stamp ~= now then
			net.status_stamp = now
			net:apply_status(status)
		end
		update_crystal(pos) -- repairs a missing crystal
		local meta = core.get_meta(pos)
		local text = ("VaultNet Core (%s)\n%s"):format(A.get_owner(pos), STATUS_TEXT[status] or status)
		if meta:get_string("infotext") ~= text then meta:set_string("infotext", text) end
	end,
})

-- Access formspec ---------------------------------------------------------------

local FORMNAME = "vaultnet_core:access"
local contexts = {} -- player -> {pos, list}
local ROW_H, VIEW_H = 0.7, 3.6

local function build(pos, name)
	local net = vaultnet.get_network(pos)
	local status = net and net:status() or "no_core"
	local used, cap = 0, 0
	if net and status == "ok" then used, cap = net:capacity() end
	local can_admin = A.can(pos, name, "admin")
	local list = A.list(pos)
	contexts[name] = {pos = pos, list = list}

	local esc = core.formspec_escape
	local fs = {
		"formspec_version[4]size[10,9.2]",
		"label[0.4,0.5;VaultNet Core]",
		("label[0.4,1.1;Owner: %s]"):format(esc(A.get_owner(pos))),
		("label[0.4,1.6;Status: %s]"):format(esc(STATUS_TEXT[status] or status)),
		("label[0.4,2.1;Network: %d devices, storage %d / %d items]"):format(
			net and net.count or 0, used, cap),
	}
	if vaultnet.require_power and vaultnet.power_info and net then
		local info = vaultnet.power_info(net)
		local text = ("Power: %d supplied / %d needed"):format(info.supply, info.demand)
		if info.capacity and info.capacity > 0 then
			text = text .. ("   Batteries: %d / %d"):format(info.stored, info.capacity)
		end
		fs[#fs + 1] = ("label[0.4,2.55;%s]"):format(core.formspec_escape(text))
	end

	if can_admin then
		fs[#fs + 1] = "label[0.4,2.9;Player access]"
		fs[#fs + 1] = "label[0.4,3.35;Player]label[4.4,3.35;Put]label[5.5,3.35;Pull]label[6.7,3.35;Admin]"
		local content_h = #list * ROW_H
		fs[#fs + 1] = ("scroll_container[0.4,3.6;8.9,%f;sb;vertical;0.1]"):format(VIEW_H)
		for i, e in ipairs(list) do
			local y = (i - 1) * ROW_H
			fs[#fs + 1] = ("label[0,%f;%s]"):format(y + 0.35, esc(e.name))
			for k, x in pairs({put = 4.0, pull = 5.1, admin = 6.3}) do
				fs[#fs + 1] = ("checkbox[%f,%f;%s_%d;;%s]"):format(x, y + 0.35, k, i,
					e[k] and "true" or "false")
			end
			fs[#fs + 1] = ("button[7.2,%f;1.5,0.6;rm_%d;Remove]"):format(y, i)
		end
		fs[#fs + 1] = "scroll_container_end[]"
		local max = math.max(0, math.ceil((content_h - VIEW_H) * 10))
		fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=7;largestep=36]"):format(max)
		fs[#fs + 1] = ("scrollbar[9.4,3.6;0.3,%f;vertical;sb;0]"):format(VIEW_H)
		fs[#fs + 1] = "field[0.4,7.9;5,0.7;newname;Add player;]"
		fs[#fs + 1] = "field_close_on_enter[newname;false]"
		fs[#fs + 1] = "button[5.6,7.9;2,0.7;add;Add]"
	else
		local perms = {}
		for _, k in ipairs(A.PERMS) do
			if A.can(pos, name, k) then perms[#perms + 1] = k end
		end
		fs[#fs + 1] = ("label[0.4,3.1;Your access: %s]"):format(
			#perms > 0 and table.concat(perms, ", ") or "none")
	end
	return table.concat(fs)
end

function show_formspec(pos, name)
	core.show_formspec(name, FORMNAME, build(pos, name))
end

local is_core = {[IDLE] = true, [ACTIVE] = true, [CONFLICT] = true}

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
	if not node or not is_core[node.name] then return true end
	local function say(msg) core.chat_send_player(name, "[VaultNet] " .. msg) end

	local changed = false
	for i, e in ipairs(ctx.list) do
		if fields["rm_" .. i] then
			changed = A.remove(pos, name, e.name) or changed
		else
			local perms, edited = {put = e.put, pull = e.pull, admin = e.admin}, false
			for _, k in ipairs(A.PERMS) do
				local v = fields[k .. "_" .. i]
				if v ~= nil and (v == "true") ~= (e[k] == true) then
					perms[k] = (v == "true")
					edited = true
				end
			end
			if edited then changed = A.set(pos, name, e.name, perms) or changed end
		end
	end

	if fields.add or fields.key_enter_field == "newname" then
		local target = (fields.newname or ""):match("^%s*(.-)%s*$")
		if target ~= "" then
			if not core.player_exists(target) then
				say("Unknown player: " .. target)
			elseif target == A.get_owner(pos) then
				say(target .. " owns this core and already has full access.")
			else
				local existing = false
				for _, e in ipairs(ctx.list) do
					if e.name == target then existing = true end
				end
				if not existing then
					changed = A.set(pos, name, target, {put = true, pull = true}) or changed
				end
			end
		end
	end

	if changed or fields.add then show_formspec(pos, name) end
	return true
end)

core.register_on_leaveplayer(function(player) contexts[player:get_player_name()] = nil end)

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
