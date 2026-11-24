-- Drive bay: holds BAY_SLOTS drives. Modelled on Refined Storage's disk drive: a
-- block with 2 columns x 4 rows of slots in its front; each inserted drive is a
-- small flat disk (an entity with a mesh) sticking out 1/16 of a node, with its
-- own LED showing fullness. The drives are the network's storage: the bay
-- provides them via get_drive_slots.

local drive = vaultnet.drive

local BAY_SLOTS = 8
local ENT = "vaultnet_drives:bay_drive"
local NODE, NODE_ACTIVE = "vaultnet_drives:bay", "vaultnet_drives:bay_active"
-- If the disks show edge-on instead of flat on the front face, set this to
-- math.pi / 2.
local YAW_OFFSET = 0

-- Slot centres in 1/16 node from the bottom-left of the front face, slot 1 top
-- left, then left to right, top to bottom. Keep in sync with
-- tools/gen_drive_textures.py (HOLE_X / HOLE_Y).
local SLOT_CENTERS = {}
for row = 0, 3 do
	for _, cx in ipairs({4, 12}) do
		SLOT_CENTERS[#SLOT_CENTERS + 1] = {cx, 14 - 4 * row}
	end
end

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
		visual = "mesh",
		mesh = "vaultnet_drives_disk.obj",
		-- entity meshes render at 1/10 of the model size, so 10 = one model unit per node
		visual_size = {x = 10, y = 10, z = 10},
		textures = {"blank.png", "blank.png"},
		physical = false,
		pointable = false,
		collide_with_objects = false,
		glow = 12, -- the disks (and their LEDs) stay visible in the dark
		static_save = false, -- recreated from the bay's inventory (LBM / ABM)
	},

	-- Remove ourselves when the bay is gone, moved, or this slot was emptied, so no
	-- stray disks linger at an old position.
	on_step = function(self, dtime)
		self.check_timer = (self.check_timer or 0) + dtime
		if self.check_timer < 2 then return end
		self.check_timer = 0
		local pos = self.bay_pos
		if not pos or not self.slot then return self.object:remove() end
		local node = core.get_node_or_nil(pos)
		if not node then return end -- area not loaded: leave it alone
		if node.name ~= NODE and node.name ~= NODE_ACTIVE then return self.object:remove() end
		if core.get_meta(pos):get_inventory():get_stack("drives", self.slot):is_empty() then
			return self.object:remove()
		end
	end,
})

-- Texture for a drive stack's disk: the tier texture with the state LED painted
-- onto the texel the LED faces of the mesh point at.
local function disk_textures(stack)
	local idef = core.registered_items[stack:get_name()]
	local def = idef and idef.vaultnet_drive
	local tex = (def and def.disk_texture or "blank.png") ..
		"^vaultnet_drives_ledpx" .. drive.state(stack) .. ".png"
	return {tex, tex}
end

-- Position of slot i (1..BAY_SLOTS) just outside the front face of the bay at pos.
local function slot_pos(pos, front, i)
	local c = SLOT_CENTERS[i]
	local right = {x = -front.z, y = 0, z = front.x} -- as seen facing the bay
	local h = (c[1] - 8) / 16
	local out = 0.5 + 0.5 / 16 -- the disk is 1/16 thick: it spans the face .. 1/16 out
	return {
		x = pos.x + front.x * out + right.x * h,
		y = pos.y + (c[2] - 8) / 16,
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

	for i = 1, BAY_SLOTS do
		local stack = inv:get_stack("drives", i)
		if not stack:is_empty() and drive.sync_flags(stack) then inv:set_stack("drives", i, stack) end
	end

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
				obj:set_properties({textures = disk_textures(stack)})
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

local COLS, ROWS = 2, 4 -- as laid out on the front of the bay

local function formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local inv = core.get_meta(pos):get_inventory()
	local fs = {
		"formspec_version[4]size[11,11.4]",
		"label[0.5,0.5;Drive Bay]",
		"list[nodemeta:", spos, ";drives;0.5,1;", COLS, ",", ROWS, ";]",
	}
	for i = 1, BAY_SLOTS do
		local info = drive.info(inv:get_stack("drives", i))
		local text = info and vaultnet.format_usage(info.used, info.capacity) or "empty"
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		fs[#fs + 1] = ("label[%f,%f;%s]"):format(3.4 + col * 3.6, 1.5 + row * 1.25,
			core.formspec_escape(text))
	end
	fs[#fs + 1] = "list[current_player;main;0.5,6.4;8,4;]"
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

local FULL = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}

local function register(name, tile, vn, extra)
	local def = {
		drawtype = "mesh",
		mesh = "vaultnet_drives_bay.obj",
		tiles = {tile}, -- one texture: frame, plus the slot interior in its last two rows
		selection_box = FULL,
		collision_box = FULL,
		paramtype = "light",
		paramtype2 = "4dir",
		groups = vaultnet.groups({vaultnet_device = 1, vaultnet_bay = 1}),
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
		consumes_power = true,
		get_drive_slots = function(pos) return vaultnet.inv_slots(pos, "drives") end,
		on_drives_changed = update_visuals,
	}
	for k, v in pairs(extra) do t[k] = v end
	return t
end

register(NODE, "vaultnet_drives_bay.png", vn({active_variant = NODE_ACTIVE}), {
	description = "VaultNet Drive Bay",
})

-- active: the slot interiors pulse blue behind the drives
register(NODE_ACTIVE, {
	name = "vaultnet_drives_bay_active.png",
	animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 18, length = 4.0},
}, vn({inactive_variant = NODE}), {
	description = "VaultNet Drive Bay (active)",
	drop = NODE,
	light_source = 2,
	groups = vaultnet.groups({vaultnet_device = 1, vaultnet_bay = 1, not_in_creative_inventory = 1}),
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
