-- The network's power budget. Demand is what its parts draw (only counted while the
-- network has exactly one core: with none or two nothing works, so nothing is drawn).
-- Supply comes from sources (generators, solar panels) and from power adapters, which
-- deliver what they pull from an external grid. Powered means supply >= demand.
--
-- Adapters are asked to cover what the other sources do not: vaultnet.power.request(pos)
-- says how many units/s this adapter should pull, sharing the shortfall between adapters
-- (by position, each up to its capacity).

local P = vaultnet.power

-- {supply, demand, local_supply, requests = {[pos hash] = units}}; cached per game second
-- per network object because is_powered is called a lot.
local function compute(net)
	local now = core.get_gametime()
	local c = net.power_cache
	if c and c.t == now then return c end

	local local_supply, adapter_supply, demand = 0, 0, 0
	local adapters = {}
	for _, pos in pairs(net.nodes) do
		local def = vaultnet.get_def(core.get_node(pos).name)
		if def then
			demand = demand + vaultnet.power_use(def)
			if def.power_adapter then
				adapters[#adapters + 1] = {hash = vaultnet.pos_hash(pos), cap = def.power_adapter.capacity or 0}
				adapter_supply = adapter_supply + (def.power_supply and def.power_supply(pos) or 0)
			elseif def.power_supply then
				local_supply = local_supply + (def.power_supply(pos) or 0)
			end
		end
	end
	if #net.cores ~= 1 then demand = 0 end

	local need = math.max(0, demand - local_supply)
	table.sort(adapters, function(a, b) return a.hash < b.hash end)
	local requests = {}
	for _, a in ipairs(adapters) do
		local r = math.min(a.cap, need)
		requests[a.hash] = r
		need = need - r
	end

	local supply = local_supply + adapter_supply
	c = {t = now, supply = supply, demand = demand, local_supply = local_supply,
		requests = requests, ok = supply >= demand}
	net.power_cache = c
	return c
end

-- supply, demand of a network (units per second).
function P.budget(net)
	local c = compute(net)
	return c.supply, c.demand
end

-- How many units per second an adapter should pull from its external grid.
function P.request(pos)
	local net = vaultnet.get_network(pos)
	if not net then return 0 end
	return compute(net).requests[vaultnet.pos_hash(pos)] or 0
end

function vaultnet.power_info(net)
	local c = compute(net)
	return {supply = c.supply, demand = c.demand}
end

-- Power handler: a part is powered while its network is.
function P.handler(pos)
	local net = vaultnet.get_network(pos)
	return net ~= nil and compute(net).ok
end
