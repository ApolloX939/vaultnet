-- VaultNet power. Only does anything when `vaultnet_require_power` is on: then every
-- part that consumes power (core, bays, terminal, Inserter, Exporter, autocrafter,
-- relay) needs it, and parts without it look inactive and do not work.
--
-- The whole network shares one power budget (see budget.lua): sources add supply, parts
-- add demand, and the network is powered while supply covers demand.
--
-- Sources:
--   Generator, Solar Panel   built in (sources.lua)
--   Power Adapters           connect the network to an external power grid; only they
--                            touch other mods' cables: vaultnet_power_technic (LV, MV and
--                            HV adapters) and vaultnet_power_techage (one adapter).
--
-- A source is a device def with `power_supply = function(pos) -> units/s`. An adapter also
-- has `power_adapter = {capacity = units/s}` and asks vaultnet.power.request(pos) how much
-- to pull from its external grid.

local modpath = core.get_modpath(core.get_current_modname())

local P = {}
vaultnet.power = P

-- Units per second each part draws (before the multiplier).
local USE = {
	core = 10, bay = 5, terminal = 2, inserter = 3, exporter = 3, autocrafter = 8, relay = 10,
}
P.default_use = USE

local mult = tonumber(core.settings:get("vaultnet_power_use_multiplier")) or 1.0
for role, n in pairs(USE) do
	vaultnet.power_use_by_role[role] = math.max(1, math.floor(n * mult + 0.5))
end

dofile(modpath .. "/budget.lua")
dofile(modpath .. "/sources.lua")

if vaultnet.require_power then
	vaultnet.register_power_handler(P.handler)
end

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
