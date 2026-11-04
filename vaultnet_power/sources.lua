-- Built-in power sources: a fuel generator and a solar panel.

local P = vaultnet.power
local GEN_OUT = tonumber(core.settings:get("vaultnet_power_generator_output")) or 60
local SOLAR_OUT = tonumber(core.settings:get("vaultnet_power_solar_output")) or 8

local GEN, GEN_ON = "vaultnet_power:generator", "vaultnet_power:generator_active"
local SOLAR = "vaultnet_power:solar"

-- Generator ------------------------------------------------------------------------

local FUEL_SLOTS = 2

local function fuel_time(stack)
	local out = core.get_craft_result({method = "fuel", width = 1, items = {stack}})
	return out.time or 0
end

local function generator_formspec(pos)
	local meta = core.get_meta(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local left = meta:get_int("burn_left")
	local net = vaultnet.get_network(pos)
	local info = net and vaultnet.power_info(net)
	local lines = {
		left > 0 and ("Burning: %d s left (%d units/s)"):format(left, GEN_OUT) or "Not burning",
	}
	if info then lines[#lines + 1] = ("Network: %d supplied / %d needed"):format(info.supply, info.demand) end
	return table.concat({
		"formspec_version[4]size[10.5,9]",
		"label[0.5,0.5;VaultNet Generator]",
		("list[nodemeta:%s;fuel;0.5,1;%d,1;]"):format(spos, FUEL_SLOTS),
		("label[0.5,2.6;%s]"):format(core.formspec_escape(table.concat(lines, "   "))),
		"list[current_player;main;0.5,3.5;8,4;]",
		("listring[nodemeta:%s;fuel]listring[current_player;main]"):format(spos),
	})
end

local function generator_tick(pos, node)
	local meta = core.get_meta(pos)
	local left = meta:get_int("burn_left")
	if left > 0 then
		left = left - 1
		meta:set_int("burn_left", left)
	end
	if left <= 0 then
		local net = vaultnet.get_network(pos)
		if net then
			local supply, demand = P.budget(net)
			-- only light the next item when the network needs more than it gets
			if demand > supply then
				local inv = meta:get_inventory()
				for i = 1, FUEL_SLOTS do
					local s = inv:get_stack("fuel", i)
					local t = s:is_empty() and 0 or fuel_time(s)
					if t > 0 then
						s:take_item(1)
						inv:set_stack("fuel", i, s)
						left = math.ceil(t)
						meta:set_int("burn_left", left)
						break
					end
				end
			end
		end
	end
	local want = left > 0 and GEN_ON or GEN
	if node.name ~= want then
		node.name = want
		core.swap_node(pos, node)
		vaultnet.schedule_refresh(pos)
	end
	meta:set_string("infotext", ("VaultNet Generator\n%s"):format(left > 0 and ("Burning (%d s)"):format(left) or "Not burning"))
end

local function register_generator(name, active)
	local side = "vaultnet_power_side.png"
	core.register_node(name, {
		description = "VaultNet Generator" .. (active and " (active)" or ""),
		paramtype2 = "4dir",
		tiles = {"vaultnet_power_generator_top.png", side, side, side, side,
			active and {
				name = "vaultnet_power_generator_front_active.png",
				animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.2},
			} or "vaultnet_power_generator_front.png"},
		inventory_image = "vaultnet_power_generator_icon.png",
		wield_image = "vaultnet_power_generator_icon.png",
		groups = {cracky = 2, vaultnet_device = 1, not_in_creative_inventory = active and 1 or nil},
		sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
		light_source = active and 8 or nil,
		drop = GEN,
		vaultnet = {
			role = "power",
			power_supply = function(pos)
				return core.get_meta(pos):get_int("burn_left") > 0 and GEN_OUT or 0
			end,
		},
		on_construct = function(pos)
			core.get_meta(pos):get_inventory():set_size("fuel", FUEL_SLOTS)
		end,
		can_dig = function(pos)
			return core.get_meta(pos):get_inventory():is_empty("fuel")
		end,
		on_rightclick = function(pos, _, clicker)
			if clicker and clicker:is_player() then
				core.show_formspec(clicker:get_player_name(), "vaultnet_power:generator", generator_formspec(pos))
			end
		end,
		allow_metadata_inventory_put = function(pos, _, _, stack, player)
			if core.is_protected(pos, player:get_player_name()) then return 0 end
			return fuel_time(stack) > 0 and stack:get_count() or 0
		end,
		allow_metadata_inventory_take = function(pos, _, _, stack, player)
			if core.is_protected(pos, player:get_player_name()) then return 0 end
			return stack:get_count()
		end,
	})
end

register_generator(GEN, false)
register_generator(GEN_ON, true)

core.register_abm({
	label = "VaultNet generator",
	nodenames = {GEN, GEN_ON},
	interval = 1,
	chance = 1,
	action = generator_tick,
})

-- Solar panel -----------------------------------------------------------------------

core.register_node(SOLAR, {
	description = "VaultNet Solar Panel",
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5}},
	selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5}},
	paramtype = "light",
	tiles = {"vaultnet_power_solar_top.png", "vaultnet_power_side.png", "vaultnet_power_side.png"},
	groups = {cracky = 2, vaultnet_device = 1},
	sounds = core.global_exists("default") and default.node_sound_metal_defaults() or nil,
	vaultnet = {
		role = "power",
		power_supply = function(pos)
			local light = core.get_natural_light({x = pos.x, y = pos.y + 1, z = pos.z}) or 0
			return light >= 13 and SOLAR_OUT or 0
		end,
	},
})
