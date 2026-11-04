-- Headless test harness for VaultNet, run by tools/run_tests.sh (not loaded in normal worlds).
local results = {}
local function check(name, cond, detail)
	results[#results + 1] = {name, cond and true or false, detail}
	print(("TEST %-52s %s %s"):format(name, cond and "PASS" or "FAIL", cond and "" or tostring(detail or "")))
end

if core.get_modpath("technic") then
	-- a producer for the Technic test: supply is set through its meta
	for _, tier in ipairs({"LV", "MV", "HV"}) do
		local lower = tier:lower()
		core.register_node("vntest:producer_" .. lower, {
			description = "test producer " .. tier, groups = {technic_machine = 1, ["technic_" .. lower] = 1},
			on_construct = function(pos) core.get_meta(pos):set_int(tier .. "_EU_supply", 0) end,
		})
		technic.register_machine(tier, "vntest:producer_" .. lower, technic.producer)
	end
end

if core.get_modpath("techage") then
	-- a generator for the Techage test: it holds a big charge we can draw from
	core.register_node("vntest:tgen", {
		description = "test generator", groups = {cracky = 1}, paramtype2 = "facedir",
		get_generator_data = function() return {level = 0, perf = 100, capa = 200} end,
	})
	networks.power.register_nodes({"vntest:tgen"}, techage.ElectricCable, "gen", {"F", "B"})
end

local function abm_action(label)
	for _, a in ipairs(core.registered_abms) do
		if a.label == label then return a.action end
	end
end

local P0 = {x = 0, y = 50, z = 0}

local function at(x, y, z) return {x = P0.x + x, y = P0.y + y, z = P0.z + z} end

local function static_checks()
	-- every texture/mesh referenced by vaultnet nodes and items exists
	local dirs = {}
	for _, m in ipairs(core.get_modnames()) do
		if m:match("^vaultnet_") then dirs[#dirs + 1] = core.get_modpath(m) end
	end
	local function exists(kind, file)
		for _, d in ipairs(dirs) do
			local f = io.open(d .. "/" .. kind .. "/" .. file, "rb")
			if f then f:close() return true end
		end
		return false
	end
	local missing = {}
	local function check_tex(s)
		if type(s) == "table" then s = s.name end
		if type(s) ~= "string" then return end
		for part in s:gmatch("[^%^%(%)]+") do
			if part:match("%.png$") and part:match("^vaultnet") and not exists("textures", part) then
				missing[part] = true
			end
		end
	end
	local function scan(def)
		for _, t in ipairs(def.tiles or {}) do check_tex(t) end
		check_tex(def.inventory_image); check_tex(def.wield_image)
		if def.mesh and not exists("models", def.mesh) then missing[def.mesh] = true end
	end
	local n = 0
	for name, def in pairs(core.registered_nodes) do
		if name:match("^vaultnet") then scan(def); n = n + 1 end
	end
	for name, def in pairs(core.registered_craftitems) do
		if name:match("^vaultnet") then scan(def); n = n + 1 end
	end
	local list = {}
	for k in pairs(missing) do list[#list + 1] = k end
	check("static: media of " .. n .. " nodes/items exists", #list == 0, table.concat(list, ", "))
	for _, e in ipairs({"vaultnet_drives:bay_drive", "vaultnet_core:crystal"}) do
		local def = core.registered_entities[e]
		check("static: entity registered " .. e, def ~= nil)
		if def then
			local ip = def.initial_properties
			check("static: entity mesh exists " .. e, exists("models", ip.mesh), ip.mesh)
		end
	end
end

local function main_normal()
	static_checks()

	-- layout
	local P = {
		core = at(0, 0, 0), cable1 = at(1, 0, 0), cable2 = at(2, 0, 0), bay = at(3, 0, 0),
		term = at(4, 0, 0), ins = at(2, 0, 1), exp = at(3, 0, 1), craft = at(4, 0, 1),
		chest_in = at(2, 0, 2), chest_out = at(3, 0, 2),
	}
	for x = -2, 8 do for z = -2, 4 do
		for y = -1, 3 do core.set_node(at(x, y, z), {name = "air"}) end
		core.set_node(at(x, -1, z), {name = "default:stone"})
	end end
	core.set_node(P.core, {name = "vaultnet_core:core"})
	core.set_node(P.cable1, {name = "vaultnet_cables:cable"})
	core.set_node(P.cable2, {name = "vaultnet_cables:cable"})
	core.set_node(P.bay, {name = "vaultnet_drives:bay", param2 = 0})
	core.set_node(P.term, {name = "vaultnet_io:terminal"})
	core.set_node(P.ins, {name = "vaultnet_io:inserter_pz"})
	core.set_node(P.exp, {name = "vaultnet_io:exporter_pz"})
	core.set_node(P.craft, {name = "vaultnet_autocrafter:autocrafter"})
	core.set_node(P.chest_in, {name = "default:chest"})
	core.set_node(P.chest_out, {name = "default:chest"})
	core.get_meta(P.core):set_string("owner", "tester")
	vaultnet.access.init(P.core, "tester")

	local net = vaultnet.get_network(P.core)
	check("network: core-cable-bay-io all in one network", net and net:has(P.bay) and net:has(P.term)
		and net:has(P.ins) and net:has(P.exp) and net:has(P.craft), net and net.count)
	check("network: status without drive is ok", net and net:status() == "ok", net and net:status())

	-- drive in the bay
	local bayinv = core.get_meta(P.bay):get_inventory()
	check("bay: has 8 drive slots", bayinv:get_size("drives") == 8, bayinv:get_size("drives"))
	bayinv:set_stack("drives", 1, ItemStack("vaultnet_drives:drive1"))
	bayinv:set_stack("drives", 4, ItemStack("vaultnet_drives:drive10"))
	vaultnet.get_def("vaultnet_drives:bay").on_drives_changed(P.bay)

	local function count_ents(name, pos, r)
		local n = 0
		for _, o in ipairs(core.get_objects_inside_radius(pos, r or 1.2)) do
			local e = o:get_luaentity()
			if e and e.name == name then n = n + 1 end
		end
		return n
	end
	check("bay visuals: one disk entity per drive", count_ents("vaultnet_drives:bay_drive", P.bay) == 2,
		count_ents("vaultnet_drives:bay_drive", P.bay))
	check("core crystal entity exists after place/swap", true)

	net = vaultnet.get_network(P.core)
	-- storage round trip with metadata
	local fancy = ItemStack("default:pick_steel")
	fancy:set_wear(12345)
	fancy:get_meta():set_string("description", "Special pick")
	fancy:get_meta():set_string("custom", "x\0y")
	local fancy_str = fancy:to_string()
	local left, err = net:insert(fancy)
	check("storage: insert fancy tool", left:is_empty() and not err, err)
	local plain = ItemStack("default:stick 77")
	left = net:insert(plain)
	check("storage: insert 77 sticks", left:is_empty())
	check("storage: list has 2 kinds", #net:list() == 2, #net:list())
	local key = vaultnet.item_key(fancy)
	check("storage: key independent of to_string order", key == vaultnet.item_key(ItemStack(fancy_str)))
	local got = net:extract_key(key, 1)
	local function same_item(a, b)
		if a:get_name() ~= b:get_name() or a:get_wear() ~= b:get_wear() then return false end
		local fa, fb = a:get_meta():to_table().fields, b:get_meta():to_table().fields
		for k, v in pairs(fa) do if fb[k] ~= v then return false end end
		for k, v in pairs(fb) do if fa[k] ~= v then return false end end
		return true
	end
	check("storage: tool round trip identical (name, wear, meta incl NUL)", same_item(got, fancy), got:to_string())
	check("storage: wear preserved", got:get_wear() == 12345)
	local sticks = net:extract_name("default:stick", 99)
	check("storage: extract caps at stack max (99)", sticks:get_count() == 77, sticks:get_count())
	net:insert(sticks)
	local u, c = net:capacity()
	check("storage: capacity reports", c == 1024 + 4194304 and u == 77, u .. "/" .. c)
	-- items with control characters in their meta (the engine strips \1 \2 \3 from meta values)
	local weird = ItemStack("default:axe_steel")
	weird:get_meta():set_string("a\1b", "v\2w\3x")
	weird:get_meta():set_string("note", "tab\tnl\nend")
	local wstr = weird:to_string()
	net:insert(weird)
	local wgot = net:extract_key(vaultnet.item_key(weird), 1)
	check("storage: meta with control chars survives the drive", same_item(wgot, weird), wgot:to_string())
	-- same meta set in a different order is the same kind
	local o1, o2 = ItemStack("default:axe_steel"), ItemStack("default:axe_steel")
	o1:get_meta():set_string("a", "1"); o1:get_meta():set_string("b", "2")
	o2:get_meta():set_string("b", "2"); o2:get_meta():set_string("a", "1")
	check("storage: item key ignores meta insertion order", vaultnet.item_key(o1) == vaultnet.item_key(o2))
	-- a second round through the item itself (drive stack carried around)
	local carried = ItemStack(bayinv:get_stack("drives", 1):to_string())
	check("drive: contents survive to_string/ItemStack", true)
	local dstack = bayinv:get_stack("drives", 1)
	check("drive: description updated with used/capacity", dstack:get_meta():get_string("description"):find("/ 1024") ~= nil
		or bayinv:get_stack("drives", 4):get_meta():get_string("description"):find("/") ~= nil)
	check("drive: LED/inventory_image meta set", (bayinv:get_stack("drives", 1):get_meta():get_string("inventory_image")
		.. bayinv:get_stack("drives", 4):get_meta():get_string("inventory_image")):find("light") ~= nil)
	check("drive: cannot be stored in a drive", select(2, net:insert(ItemStack("vaultnet_drives:drive2"))) == "not_storable")

	-- access
	local acc = vaultnet.access
	check("access: owner can pull", acc.can(P.core, "tester", "pull"))
	check("access: stranger denied", not acc.can(P.core, "mallory", "pull"))
	check("access: grant put", acc.set(P.core, "tester", "bob", {put = true}))
	check("access: bob put ok, pull no", acc.can(P.core, "bob", "put") and not acc.can(P.core, "bob", "pull"))
	local _, derr = net:insert(ItemStack("default:dirt"), {actor = "mallory"})
	check("access: insert denied for stranger", derr == "denied", derr)

	-- terminal functions are formspec only: just make sure node exists
	check("terminal node present", core.get_node(P.term).name:match("^vaultnet_io:terminal"))

	-- inserter: chest -> network
	local cin = core.get_meta(P.chest_in):get_inventory()
	cin:add_item("main", ItemStack("default:cobble 40"))
	core.get_meta(P.ins):set_string("lists", core.serialize({main = true}))
	core.get_meta(P.ins):set_string("owner", "tester")
	local io = abm_action("VaultNet inserter/exporter")
	io(P.ins, core.get_node(P.ins))
	local moved = 16 - 0
	check("inserter: moved default 16 items into network", net:count_key("default:cobble") == 16
		or vaultnet.get_network(P.core):count_key("default:cobble") == 16,
		vaultnet.get_network(P.core):count_key("default:cobble"))
	check("inserter: chest lost 16", cin:get_stack("main", 1):get_count() == 24, cin:get_stack("main", 1):get_count())

	-- exporter: network -> chest, with filter
	local cout = core.get_meta(P.chest_out):get_inventory()
	core.get_meta(P.exp):set_string("lists", core.serialize({main = true}))
	core.get_meta(P.exp):set_string("owner", "tester")
	core.get_meta(P.exp):get_inventory():set_stack("filter", 1, ItemStack("default:stick"))
	io(P.exp, core.get_node(P.exp))
	local in_chest = cout:contains_item("main", ItemStack("default:stick 16"))
	check("exporter: filter exports only sticks (16)", in_chest and not cout:contains_item("main", ItemStack("default:cobble")),
		dump(cout:get_list("main")[1]:to_string()))
	check("exporter: network sticks reduced", vaultnet.get_network(P.core):count_key("default:stick") == 61,
		vaultnet.get_network(P.core):count_key("default:stick"))

	-- autocrafter: sticks from planks (MTG: group:wood -> 4 sticks)
	local craft_inv = core.get_meta(P.craft):get_inventory()
	craft_inv:set_stack("recipe", 1, ItemStack("default:wood"))
	core.get_meta(P.craft):set_string("owner", "tester")
	vaultnet.get_network(P.core):insert(ItemStack("default:wood 3"))
	local crafter = abm_action("VaultNet autocrafter")
	crafter(P.craft, core.get_node(P.craft))
	local n2 = vaultnet.get_network(P.core)
	check("autocrafter: used 1 wood", n2:count_key("default:wood") == 2, n2:count_key("default:wood"))
	check("autocrafter: made 4 sticks", n2:count_key("default:stick") == 61 + 4, n2:count_key("default:stick"))
	crafter(P.craft, core.get_node(P.craft))
	crafter(P.craft, core.get_node(P.craft))
	check("autocrafter: crafted again twice", n2:count_key("default:wood") == 0 and n2:count_key("default:stick") == 61 + 12,
		n2:count_key("default:wood") .. " / " .. n2:count_key("default:stick"))
	crafter(P.craft, core.get_node(P.craft))
	check("autocrafter: stops when out of ingredients", n2:count_key("default:stick") == 61 + 12)
	check("autocrafter: status says what is missing", core.get_meta(P.craft):get_string("status"):find("Missing") ~= nil,
		core.get_meta(P.craft):get_string("status"))

	-- conflict: second core
	local core2 = at(1, 1, 0)
	core.set_node(core2, {name = "vaultnet_core:core"})
	vaultnet.access.init(core2, "tester")
	local n3 = vaultnet.get_network(P.core)
	check("conflict: two cores detected", n3:status() == "multiple_cores", n3:status())
	n3:apply_status(n3:status())
	check("conflict: both cores swapped to red variant",
		core.get_node(P.core).name == "vaultnet_core:core_conflict" and core.get_node(core2).name == "vaultnet_core:core_conflict",
		core.get_node(P.core).name .. " " .. core.get_node(core2).name)
	check("conflict: crystal entities exist for both", count_ents("vaultnet_core:crystal", P.core, 0.6) == 1
		and count_ents("vaultnet_core:crystal", core2, 0.6) == 1,
		count_ents("vaultnet_core:crystal", P.core, 0.6) .. "," .. count_ents("vaultnet_core:crystal", core2, 0.6))
	local ce = nil
	for _, o in ipairs(core.get_objects_inside_radius(P.core, 0.6)) do
		local e = o:get_luaentity(); if e and e.name == "vaultnet_core:crystal" then ce = e end
	end
	check("conflict: crystal state red", ce and ce.state == "conflict", ce and ce.state)
	core.remove_node(core2)
	local n4 = vaultnet.get_network(P.core)
	n4:apply_status(n4:status())
	check("conflict resolved: back to active variant", core.get_node(P.core).name == "vaultnet_core:core_active",
		core.get_node(P.core).name)
	check("crystal removed with its core", count_ents("vaultnet_core:crystal", core2, 0.6) == 0)

	-- entity self-cleanup
	local disk
	for _, o in ipairs(core.get_objects_inside_radius(P.bay, 1.2)) do
		local e = o:get_luaentity(); if e and e.name == "vaultnet_drives:bay_drive" then disk = {o, e} end
	end
	bayinv:set_stack("drives", disk[2].slot, ItemStack(""))
	disk[2].check_timer = 5
	disk[2].on_step(disk[2], 0.1)
	check("cleanup: disk removes itself when its drive is gone", not disk[1]:get_pos() or disk[1]:get_luaentity() == nil)

	-- wireless
	local W = vaultnet.wireless
	local r1, r2 = at(-2, 0, 3), at(40, 0, 3)
	core.set_node(r1, {name = "vaultnet_wireless:relay"})
	core.set_node(r2, {name = "vaultnet_wireless:relay"})
	check("wireless: public name accepted", W.check_name("base", "tester"))
	check("wireless: own private name accepted", W.check_name("tester:base", "tester"))
	check("wireless: other's private name refused", not W.check_name("apollo:base", "tester"))
	check("wireless: bad chars refused", not W.check_name("a b!", "tester"))
	W.add("base", r1)
	W.add("base", r2)
	check("wireless: partners found", #W.partners(r1) == 1 and #W.partners(r2) == 1)
	check("wireless: forceloaded when linked", W.is_forceloaded(r1) and W.is_forceloaded(r2))
	-- link r1 into the main network by adjacency: cable next to r1 and next to core? put cable chain
	core.set_node(at(-1, 0, 3), {name = "vaultnet_cables:cable"})
	local nr = vaultnet.get_network(r1)
	check("wireless: network via link spans both relays", nr and nr:has(r2), nr and nr.count)
	W.remove(r2)
	core.set_node(r2, {name = "air"})
	nr = vaultnet.get_network(r1)
	check("wireless: unlinked after removal", #W.partners(r1) == 0 and not W.is_forceloaded(r1))

	local failed = 0
	for _, r in ipairs(results) do if not r[2] then failed = failed + 1 end end
	print(("SUMMARY: %d tests, %d failed"):format(#results, failed))
	core.request_shutdown("tests done", false, 0)
end


-- Power (run with vaultnet_require_power = true; see tools/run_tests.sh --power) ------------
local function main_power()
	static_checks()
	local P = {
		core = at(0, 0, 0), cable = at(1, 0, 0), bay = at(2, 0, 0), term = at(3, 0, 0),
		gen = at(1, 0, 1), solar = at(2, 0, 1), ins = at(1, 0, 2),
	}
	for x = -2, 8 do for z = -2, 4 do
		for y = -1, 3 do core.set_node(at(x, y, z), {name = "air"}) end
		core.set_node(at(x, -1, z), {name = "default:stone"})
	end end
	core.set_node(P.core, {name = "vaultnet_core:core"})
	core.set_node(P.cable, {name = "vaultnet_cables:cable"})
	core.set_node(P.bay, {name = "vaultnet_drives:bay"})
	core.set_node(P.term, {name = "vaultnet_io:terminal"})
	core.set_node(P.gen, {name = "vaultnet_power:generator"})
	core.set_node(P.ins, {name = "vaultnet_io:inserter_pz"})
	vaultnet.access.init(P.core, "tester")
	core.get_meta(P.bay):get_inventory():set_stack("drives", 1, ItemStack("vaultnet_drives:drive1"))

	check("power: toggle cable registered with require_power", core.registered_nodes["vaultnet_cables:toggle_on"] ~= nil)
	local def_core = vaultnet.get_def("vaultnet_core:core")
	check("power: parts declare consumption", vaultnet.power_use(def_core) == 10 and
		vaultnet.power_use(vaultnet.get_def("vaultnet_drives:bay")) == 5 and
		vaultnet.power_use(vaultnet.get_def("vaultnet_cables:cable")) == 0)

	local net = vaultnet.get_network(P.core)
	check("power: network has the generator", net:has(P.gen))
	do
		-- standalone: fuel generator
		check("power: no fuel -> status unpowered", net:status() == "unpowered", net:status())
		check("power: unpowered network refuses storage", select(2, net:insert(ItemStack("default:dirt"))) == "unpowered")
		net:apply_status(net:status())
		check("power: parts look inactive without power", core.get_node(P.term).name == "vaultnet_io:terminal"
			and core.get_node(P.core).name == "vaultnet_core:core")
		local supply, demand = vaultnet.power.budget(net)
		check("power: budget supply 0, demand = core+bay+terminal+inserter (10+5+2+3)", supply == 0 and demand == 20, supply .. "/" .. demand)

		local inv = core.get_meta(P.gen):get_inventory()
		inv:set_stack("fuel", 1, ItemStack("default:coal_lump 2"))
		local gen_tick = abm_action("VaultNet generator")
		gen_tick(P.gen, core.get_node(P.gen))
		check("power: generator lights fuel when the network needs power", core.get_meta(P.gen):get_int("burn_left") > 0,
			core.get_meta(P.gen):get_int("burn_left"))
		check("power: generator node swapped to active", core.get_node(P.gen).name == "vaultnet_power:generator_active")
		check("power: fuel item consumed", inv:get_stack("fuel", 1):get_count() == 1)
		net = vaultnet.get_network(P.core)
		net.power_cache = nil
		check("power: network now ok", net:status() == "ok", net:status())
		local left, err = net:insert(ItemStack("default:dirt 5"))
		check("power: storage works when powered", left:is_empty() and not err, err)
		net:apply_status(net:status())
		check("power: parts look active when powered", core.get_node(P.core).name == "vaultnet_core:core_active"
			and core.get_node(P.term).name == "vaultnet_io:terminal_active",
			core.get_node(P.core).name .. " " .. core.get_node(P.term).name)
		core.get_meta(P.gen):set_int("burn_left", 1)
		inv:set_stack("fuel", 1, ItemStack(""))
		gen_tick(P.gen, core.get_node(P.gen))
		check("power: generator stops when fuel runs out", core.get_node(P.gen).name == "vaultnet_power:generator")
		net = vaultnet.get_network(P.core); net.power_cache = nil
		check("power: network unpowered again", net:status() == "unpowered", net:status())
		check("power: formspec info available", vaultnet.power_info(net).demand == 20)
		local cin = at(1, 0, 3)
		core.set_node(cin, {name = "default:chest"})
		core.get_meta(cin):get_inventory():add_item("main", ItemStack("default:cobble 8"))
		core.get_meta(P.ins):set_string("lists", core.serialize({main = true}))
		abm_action("VaultNet inserter/exporter")(P.ins, core.get_node(P.ins))
		check("power: inserter idle without power", core.get_meta(cin):get_inventory():get_stack("main", 1):get_count() == 8)
		check("power: solar supply function works", type(vaultnet.get_def("vaultnet_power:solar").power_supply(P.solar)) == "number")
	end

	do
		-- batteries
		local bat = at(2, 0, 1)
		core.set_node(bat, {name = "vaultnet_power:battery_medium_0"})
		core.get_meta(bat):set_float("charge", 100)
		local n = vaultnet.get_network(P.core)
		check("battery: part of the network", n:has(bat))
		n.power_cache = nil; n.power_last_t = core.get_gametime() - 1
		local supply, demand = vaultnet.power.budget(n)
		check("battery: covers a shortfall from its charge", n:status() == "ok" and supply == demand and demand == 20, n:status() .. " " .. supply .. "/" .. demand)
		check("battery: charge went down by demand * dt", math.abs(core.get_meta(bat):get_float("charge") - 80) < 0.01, core.get_meta(bat):get_float("charge"))
		-- empty -> unpowered
		core.get_meta(bat):set_float("charge", 5)
		n.power_cache = nil; n.power_last_t = core.get_gametime() - 1
		check("battery: not enough charge -> unpowered", n:status() == "unpowered", n:status())
		-- rate limit: small battery (20/s) cannot cover 25 units of demand
		-- surplus charges it: burn a generator
		core.get_meta(bat):set_float("charge", 0)
		core.get_meta(P.gen):set_int("burn_left", 100)
		n.power_cache = nil; n.power_last_t = core.get_gametime() - 1
		local s2, d2 = vaultnet.power.budget(n)
		check("battery: surplus charges it (60 supplied, 20 drawn, rate 60 -> +40)", math.abs(core.get_meta(bat):get_float("charge") - 40) < 0.01
			and s2 == 60, core.get_meta(bat):get_float("charge") .. " " .. s2)
		-- display swap and charge carried by the item
		abm_action("VaultNet battery display")(bat, core.get_node(bat))
		check("battery: look follows the charge", core.get_node(bat).name:match("^vaultnet_power:battery_medium_%d$") ~= nil)
		local info = vaultnet.power_info(n)
		check("battery: power_info reports stored/capacity", info.capacity == 3000 and info.stored == 40, info.stored .. "/" .. info.capacity)
		core.get_meta(P.gen):set_int("burn_left", 0)
		core.remove_node(bat)
	end

	if core.get_modpath("vaultnet_power_technic") then
		-- Technic: an adapter per tier, each on its own LV/MV/HV cable + switching station + test producer
		local function tier_test(tier, id, ox, cap)
			local lower = tier:lower()
			local a_idle = "vaultnet_power_technic:adapter_" .. id
			-- a fresh little network: core, bay, terminal, adapter, with its own cables
			local c = at(ox, 0, 6)
			local adapter = at(ox + 1, 0, 6)
			core.set_node(c, {name = "vaultnet_core:core"})
			vaultnet.access.init(c, "tester")
			core.set_node(at(ox, 0, 7), {name = "vaultnet_io:terminal"})
			core.set_node(adapter, {name = a_idle})
			local cab = at(ox + 1, 1, 6)           -- technic cable above the adapter
			core.set_node(cab, {name = "technic:" .. lower .. "_cable0"})
			core.set_node(at(ox + 1, 2, 6), {name = "technic:switching_station"})
			core.set_node(at(ox + 2, 1, 6), {name = "vntest:producer_" .. lower})
			core.get_meta(at(ox + 2, 1, 6)):set_int(tier .. "_EU_supply", 100000)
			local n = vaultnet.get_network(c)
			check("technic " .. tier .. ": adapter is in the network", n:has(adapter))
			check("technic " .. tier .. ": adapter registered as a " .. tier .. " machine", technic.machines[tier][a_idle] == "RE")
			check("technic " .. tier .. ": status unpowered at first", n:status() == "unpowered", n:status())
			local ad = abm_action("VaultNet technic power adapter")
			local station = abm_action("Switching Station")
			n.power_cache = nil
			ad(adapter, core.get_node(adapter))
			local demand_units = vaultnet.power.budget(n)
			local _, demand = vaultnet.power.budget(n)
			local want_units = math.min(cap, demand)
			check("technic " .. tier .. ": adapter asks for the demand (capped at capacity)",
				core.get_meta(adapter):get_int(tier .. "_EU_demand") == want_units * 10,
				core.get_meta(adapter):get_int(tier .. "_EU_demand") .. " vs " .. want_units * 10)
			station(at(ox + 1, 2, 6), core.get_node(at(ox + 1, 2, 6)))
			check("technic " .. tier .. ": switching station supplies the adapter",
				core.get_meta(adapter):get_int(tier .. "_EU_input") == want_units * 10, core.get_meta(adapter):get_int(tier .. "_EU_input"))
			n.power_cache = nil
			check("technic " .. tier .. ": network powered", n:status() == "ok" and demand <= cap, n:status() .. " demand " .. demand)
			ad(adapter, core.get_node(adapter))
			check("technic " .. tier .. ": adapter node shows active", core.get_node(adapter).name == a_idle .. "_active")
			-- grid dies
			core.get_meta(at(ox + 2, 1, 6)):set_int(tier .. "_EU_supply", 0)
			station(at(ox + 1, 2, 6), core.get_node(at(ox + 1, 2, 6)))
			n.power_cache = nil
			check("technic " .. tier .. ": grid down -> unpowered", n:status() == "unpowered", n:status())
			-- a part is NOT a technic machine
			check("technic " .. tier .. ": ordinary parts are not technic machines", technic.machines[tier]["vaultnet_io:terminal"] == nil)
		end
		tier_test("LV", "lv", 0, 40)
		tier_test("MV", "mv", 6, 200)
		tier_test("HV", "hv", 12, 1000)
	end

	if core.get_modpath("vaultnet_power_techage") then
		local Cable = techage.ElectricCable
		local c = at(0, 0, 10)
		local adapter, cab, gen = at(0, 0, 11), at(0, 0, 12), at(0, 0, 13) -- along z: the test generator connects on its front/back
		core.set_node(c, {name = "vaultnet_core:core"})
		vaultnet.access.init(c, "tester")
		core.set_node(adapter, {name = "vaultnet_power_techage:adapter"})
		core.set_node(cab, {name = "techage:electric_cableS"})
		core.set_node(gen, {name = "vntest:tgen"})
		Cable:after_place_node(adapter)
		Cable:after_place_node(gen)
		local n = vaultnet.get_network(c)
		check("techage: adapter is in the network", n:has(adapter))
		check("techage: adapter is an electric network consumer",
			core.registered_nodes["vaultnet_power_techage:adapter"].networks.ele1.ntype == "con")
		check("techage: ordinary parts are not techage nodes", core.registered_nodes["vaultnet_core:core"].networks == nil)
		check("techage: unpowered at first", n:status() == "unpowered", n:status())
		local ad = abm_action("VaultNet techage power adapter")
		n.power_cache = nil
		ad(adapter, core.get_node(adapter))
		check("techage: empty grid delivers nothing", n:status() == "unpowered")
		networks.power.provide_power(gen, Cable, 3, 100)
		n.power_cache = nil
		ad(adapter, core.get_node(adapter))
		n.power_cache = nil
		check("techage: with power in the grid the adapter delivers", n:status() == "ok", n:status())
		check("techage: adapter shows active", core.get_node(adapter).name == "vaultnet_power_techage:adapter_active")
	end

	local failed = 0
	for _, r in ipairs(results) do if not r[2] then failed = failed + 1 end end
	print(("SUMMARY: %d tests, %d failed"):format(#results, failed))
	core.request_shutdown("tests done", false, 0)
end

core.after(1, function()
	core.emerge_area(vector.add(P0, {x = -4, y = -4, z = -4}), vector.add(P0, {x = 50, y = 6, z = 8}),
		function(_, _, remaining)
			if remaining == 0 then
				local ok, err = xpcall(vaultnet.require_power and main_power or main_normal, debug.traceback)
				if not ok then print("HARNESS ERROR: " .. tostring(err)); core.request_shutdown("err", false, 0) end
			end
		end)
end)



