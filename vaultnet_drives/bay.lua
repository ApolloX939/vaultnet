-- Drive bay: holds BAY_SLOTS drives and shows each one on its front face
-- (an upright_sprite entity per drive, with its fullness light). The drives
-- are the network's storage: the bay provides them via get_drive_slots.

local drive = vaultnet.drive

local BAY_SLOTS = 8        -- 4 columns x 2 rows
local COLS, ROWS = 4, 2
local ENT = "vaultnet_drives:bay_drive"
local NODE, NODE_ACTIVE = "vaultnet_drives:bay", "vaultnet_drives:bay_active"
local ICON_SIZE = 0.36
-- If the sprites show edge-on instead of flat on the front face, set this
-- to math.pi / 2.
local YAW_OFFSET = 0

local function protected(pos, player)
	local name = player and player:get_player_name() or ""
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return true
	end
	return false
end

-- Visuals ---------------------------------------------------------------------

core.register_entity(ENT, {
	initial_properties = {
		visual = "upright_sprite",
		visual_size = {x = ICON_SIZE, y = ICON_SIZE},
		textures = {"blank.png", "blank.png"},
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false, -- recreated from the bay's inventory (LBM / ABM)
	},
})

local function drive_texture(stack)
	local idef = core.registered_items[stack:get_name()]
	local def = idef and idef.vaultnet_drive
	if def and def.state_image then
		return def.state_image(drive.state(stack))
	end
	return (idef and idef.inventory_image) or "blank.png"
end

-- Position of slot i (1..BAY_SLOTS) on the front face of the bay at pos.
local function slot_pos(pos, front, i)
	local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
	local right = {x = -front.z, y = 0, z = front.x} -- as seen facing the bay
	local h = (col - (COLS - 1) / 2) * (1 / COLS)
	local v = 0.25 - row * (1 / ROWS)
	local out = 0.51
	return {
		x = pos.x + front.x * out + right.x * h,
		y = pos.y + v,
		z = pos.z + front.z * out + right.z * h,
	}
end

local function update_visuals(pos)
	local node = core.get_node_or_nil(pos)
	if not node or (node.name ~= NODE and node.name ~= NODE_ACTIVE) then return end
	local inv = core.get_meta(pos):get_inventory()
	local back = core.facedir_to_dir(node.param2 % 4)
	local front = {x = -back.x, y = 0, z = -back.z}
	local yaw = core.dir_to_yaw(front) + YAW_OFFSET

	local have = {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 1.0)) do
		local e = obj:get_luaentity()
		if e and e.name == ENT and e.bay_pos and vector.equals(e.bay_pos, pos) then
			if have[e.slot] or inv:get_stack("drives", e.slot):is_empty() then
				obj:remove()
			else
				have[e.slot] = obj
			end
		end
	end

	for i = 1, BAY_SLOTS do
		local stack = inv:get_stack("drives", i)
		if not stack:is_empty() then
			local obj = have[i]
			if not obj then
				obj = core.add_entity(slot_pos(pos, front, i), ENT)
				if obj then
					local e = obj:get_luaentity()
					e.bay_pos = vector.copy(pos)
					e.slot = i
				end
			end
			if obj then
				local tex = drive_texture(stack)
				obj:set_properties({textures = {tex, tex}})
				obj:set_yaw(yaw)
				obj:set_pos(slot_pos(pos, front, i))
			end
		end
	end
end

local function clear_visuals(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 1.0)) do
		local e = obj:get_luaentity()
		if e and e.name == ENT and e.bay_pos and vector.equals(e.bay_pos, pos) then
			obj:remove()
		end
	end
end

-- Formspec --------------------------------------------------------------------

local function formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local inv = core.get_meta(pos):get_inventory()
	local fs = {
		"formspec_version[4]size[11,9.75]",
		"label[0.5,0.5;Drive Bay]",
		"list[nodemeta:", spos, ";drives;0.5,1;", COLS, ",", ROWS, ";]",
	}
	for i = 1, BAY_SLOTS do
		local info = drive.info(inv:get_stack("drives", i))
		local text = info and ("%d: %d / %d"):format(i, info.used, info.capacity)
			or ("%d: empty"):format(i)
		fs[#fs + 1] = ("label[6.2,%f;%s]"):format(1.2 + (i - 1) * 0.4, core.formspec_escape(text))
	end
	fs[#fs + 1] = "list[current_player;main;0.5,4.5;8,4;]"
	fs[#fs + 1] = "listring[nodemeta:" .. spos .. ";drives]listring[current_player;main]"
	return table.concat(fs)
end

-- Nodes -----------------------------------------------------------------------

local function drops_of(inv)
	local out = {}
	for i = 1, BAY_SLOTS do
		local s = inv:get_stack("drives", i)
		if not s:is_empty() then out[#out + 1] = s end
	end
	return out
end

local function register(name, front, vn, extra)
	local def = {
		paramtype2 = "4dir",
		tiles = {
			"vaultnet_drives_bay_side.png", "vaultnet_drives_bay_side.png",
			"vaultnet_drives_bay_side.png", "vaultnet_drives_bay_side.png",
			"vaultnet_drives_bay_side.png", front,
		},
		groups = {cracky = 2, vaultnet_device = 1, vaultnet_bay = 1},
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		vaultnet = vn,

		on_construct = function(pos)
			core.get_meta(pos):get_inventory():set_size("drives", BAY_SLOTS)
		end,
		on_destruct = clear_visuals,
		after_place_node = function(pos) update_visuals(pos) end,
		on_rightclick = function(pos, _, clicker)
			if not clicker or not clicker:is_player() then return end
			core.show_formspec(clicker:get_player_name(), "vaultnet_drives:bay", formspec(pos))
		end,
		can_dig = function(pos)
			return core.get_meta(pos):get_inventory():is_empty("drives")
		end,
		on_blast = function(pos)
			local drops = drops_of(core.get_meta(pos):get_inventory())
			drops[#drops + 1] = ItemStack(NODE)
			core.remove_node(pos)
			return drops
		end,

		allow_metadata_inventory_put = function(pos, _, _, stack, player)
			if protected(pos, player) or not drive.is_drive(stack) then return 0 end
			return stack:get_count()
		end,
		allow_metadata_inventory_take = function(pos, _, _, stack, player)
			if protected(pos, player) then return 0 end
			return stack:get_count()
		end,
		allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
			if protected(pos, player) then return 0 end
			return count
		end,
		on_metadata_inventory_put = function(pos) update_visuals(pos) end,
		on_metadata_inventory_take = function(pos) update_visuals(pos) end,
		on_metadata_inventory_move = function(pos) update_visuals(pos) end,
	}
	for k, v in pairs(extra) do def[k] = v end
	core.register_node(name, def)
end

local function vn(extra)
	local t = {
		role = "bay",
		get_drive_slots = function(pos) return vaultnet.inv_slots(pos, "drives") end,
		on_drives_changed = update_visuals,
	}
	for k, v in pairs(extra) do t[k] = v end
	return t
end

register(NODE, "vaultnet_drives_bay_front.png", vn({active_variant = NODE_ACTIVE}), {
	description = "VaultNet Drive Bay",
})

register(NODE_ACTIVE, "vaultnet_drives_bay_front_active.png", vn({inactive_variant = NODE}), {
	description = "VaultNet Drive Bay (active)",
	drop = NODE,
	light_source = 2,
	groups = {cracky = 2, vaultnet_device = 1, vaultnet_bay = 1, not_in_creative_inventory = 1},
})

-- Entities are not saved: bring them back when the area loads, and repair
-- any that went missing.
core.register_lbm({
	name = "vaultnet_drives:restore_bay_visuals",
	nodenames = {NODE, NODE_ACTIVE},
	run_at_every_load = true,
	action = update_visuals,
})

core.register_abm({
	label = "VaultNet drive bay visuals",
	nodenames = {NODE, NODE_ACTIVE},
	interval = 30,
	chance = 1,
	action = update_visuals,
})
