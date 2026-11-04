-- The network's power budget. Demand is what its parts draw (only counted while the
-- network has exactly one core: with none or two nothing works, so nothing is drawn).
-- Supply comes from sources (generators, solar panels), from power adapters, which
-- deliver what they pull from an external grid, and from batteries, which cover a
-- shortfall from their charge and soak up a surplus. Powered means supply >= demand.
--
-- Adapters are asked to cover what the other sources do not (and to keep the batteries
-- charging): vaultnet.power.request(pos) says how many units/s an adapter should pull,
-- sharing that between adapters (by position, each up to its capacity).
--
-- A part's draw is vaultnet.power_use(def) (by role), or def.power_draw(pos) when it
-- varies (machines draw more while they work).
--
-- Batteries are devices with `power_battery = {capacity, rate}` (capacity in unit-seconds,
-- rate in units/s); their charge is the node meta float "charge".

local P = vaultnet.power

local function draw_of(def, pos)
	if def.consumes_power and def.power_draw then return def.power_draw(pos) or 0 end
	return vaultnet.power_use(def)
end

-- Cached for a game second per network object because is_powered is called a lot.
local function compute(net)
	local now = core.get_gametime()
	local c = net.power_cache
	if c and c.t == now then return c end
	local dt = math.min(math.max(now - (net.power_last_t or now - 1), 1), 5)
	net.power_last_t = now

	local local_supply, adapter_supply, demand = 0, 0, 0
	local adapters, batteries = {}, {}
	for _, pos in pairs(net.nodes) do
		local def = vaultnet.get_def(core.get_node(pos).name)
		if def then
			demand = demand + draw_of(def, pos)
			if def.power_battery then
				local meta = core.get_meta(pos)
				batteries[#batteries + 1] = {
					hash = vaultnet.pos_hash(pos), meta = meta,
					cap = def.power_battery.capacity, rate = def.power_battery.rate,
					charge = math.min(meta:get_float("charge"), def.power_battery.capacity),
				}
			elseif def.power_adapter then
				adapters[#adapters + 1] = {hash = vaultnet.pos_hash(pos), cap = def.power_adapter.capacity or 0}
				adapter_supply = adapter_supply + (def.power_supply and def.power_supply(pos) or 0)
			elseif def.power_supply then
				local_supply = local_supply + (def.power_supply(pos) or 0)
			end
		end
	end
	if #net.cores ~= 1 then demand = 0 end
	table.sort(batteries, function(a, b) return a.hash < b.hash end)

	-- batteries: cover a shortfall, soak up a surplus
	local sources = local_supply + adapter_supply
	local battery_supply, stored, capacity, charge_want = 0, 0, 0, 0
	local deficit, surplus = demand - sources, sources - demand
	for _, b in ipairs(batteries) do
		if deficit > 0 then
			local give = math.min(b.rate, b.charge / dt, deficit)
			if give > 0 then
				b.charge = b.charge - give * dt
				deficit = deficit - give
				battery_supply = battery_supply + give
			end
		elseif surplus > 0 then
			local take = math.min(b.rate, (b.cap - b.charge) / dt, surplus)
			if take > 0 then
				b.charge = b.charge + take * dt
				surplus = surplus - take
			end
		end
		b.meta:set_float("charge", b.charge)
		stored, capacity = stored + b.charge, capacity + b.cap
		if b.charge < b.cap then charge_want = charge_want + math.min(b.rate, b.cap - b.charge) end
	end

	-- adapters cover what the other sources do not, plus charging
	local need = math.max(0, demand + charge_want - local_supply)
	table.sort(adapters, function(a, b) return a.hash < b.hash end)
	local requests = {}
	for _, a in ipairs(adapters) do
		local r = math.min(a.cap, need)
		requests[a.hash] = r
		need = need - r
	end

	local supply = sources + battery_supply
	c = {t = now, supply = supply, demand = demand, local_supply = local_supply,
		requests = requests, ok = supply >= demand, stored = stored, capacity = capacity}
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
	return {supply = c.supply, demand = c.demand, stored = c.stored, capacity = c.capacity}
end

-- Power handler: a part is powered while its network is.
function P.handler(pos)
	local net = vaultnet.get_network(pos)
	return net ~= nil and compute(net).ok
end
