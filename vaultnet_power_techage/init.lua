-- Techage backend for vaultnet_power. Every part that consumes power becomes a consumer
-- on Techage's electric cable network ("ele1"): put a Techage electric cable (or any
-- node of that network) against a part and it draws from the network's generators and
-- storage. Techage works in 2 second cycles, so a part takes ceil(units per second / 2)
-- units each cycle; if it gets them all it counts as powered for the next few seconds.

local P = vaultnet.power
local CYCLE = 2          -- seconds between draws
local GRACE = 4          -- seconds a part stays powered after a successful draw

local function per_cycle(def)
	return math.max(1, math.ceil(vaultnet.power_use(def) * CYCLE / 4))
end

local function cable() return techage.ElectricCable end

P.register_backend("techage", {
	available = function()
		return rawget(_G, "techage") ~= nil and techage.ElectricCable ~= nil
			and rawget(_G, "networks") ~= nil and networks.power ~= nil
	end,

	init = function()
		local names = {}
		for name, def in pairs(core.registered_nodes) do
			if def.vaultnet and vaultnet.power_use(def.vaultnet) > 0 then names[#names + 1] = name end
		end
		networks.power.register_nodes(names, cable(), "con")
		for _, name in ipairs(names) do
			local def = core.registered_nodes[name]
			local after_place, after_dig = def.after_place_node, def.after_dig_node
			core.override_item(name, {
				after_place_node = function(pos, ...)
					if after_place then after_place(pos, ...) end
					cable():after_place_node(pos)
				end,
				after_dig_node = function(pos, ...)
					if after_dig then after_dig(pos, ...) end
					cable():after_dig_node(pos)
				end,
			})
		end
		core.log("action", ("[vaultnet_power_techage] %d part nodes registered as consumers"):format(#names))
	end,

	handler = function(pos)
		return core.get_meta(pos):get_int("vn_power_until") >= core.get_gametime()
	end,
})

-- Draw power for every part, once per cycle.
core.register_abm({
	label = "VaultNet techage power draw",
	nodenames = {"group:vaultnet_device"},
	interval = CYCLE,
	chance = 1,
	action = function(pos, node)
		if P.active ~= "techage" then return end
		local def = vaultnet.get_def(node.name)
		if not def or vaultnet.power_use(def) <= 0 then return end
		local need = per_cycle(def)
		local got = networks.power.consume_power(pos, cable(), nil, need)
		if got >= need then
			core.get_meta(pos):set_int("vn_power_until", core.get_gametime() + GRACE)
		end
	end,
})
