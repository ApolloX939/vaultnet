-- Technic backend for vaultnet_power. Every part that consumes power becomes a Technic
-- LV receiver: put an LV cable next to it (any side) and it draws its demand from that
-- network's switching station. A part is powered when it receives its full demand.

local P = vaultnet.power
local TIER = "LV"

P.register_backend("technic", {
	available = function() return rawget(_G, "technic") ~= nil and technic.machines ~= nil end,

	init = function()
		local n = 0
		for name, def in pairs(core.registered_nodes) do
			local vn = def.vaultnet
			if vn and vaultnet.power_use(vn) > 0 then
				local use = vaultnet.power_use(vn)
				local groups = {}
				for k, v in pairs(def.groups or {}) do groups[k] = v end
				groups.technic_machine = 1
				groups["technic_" .. TIER:lower()] = 1
				local on_construct = def.on_construct
				core.override_item(name, {
					groups = groups,
					on_construct = function(pos)
						if on_construct then on_construct(pos) end
						core.get_meta(pos):set_int(TIER .. "_EU_demand", use)
					end,
				})
				technic.register_machine(TIER, name, technic.receiver)
				n = n + 1
			end
		end
		core.log("action", ("[vaultnet_power_technic] %d part nodes registered as %s consumers"):format(n, TIER))
	end,

	handler = function(pos, _, def)
		local use = vaultnet.power_use(def)
		if use <= 0 then return true end
		local meta = core.get_meta(pos)
		-- nodes placed before this backend existed learn their demand here
		if meta:get_int(TIER .. "_EU_demand") ~= use then meta:set_int(TIER .. "_EU_demand", use) end
		return meta:get_int(TIER .. "_EU_input") >= use
	end,
})
