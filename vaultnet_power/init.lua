-- VaultNet power. Only does anything when `vaultnet_require_power` is on: then every
-- part that consumes power (core, bays, terminal, Inserter, Exporter, autocrafter,
-- relay) needs it, and parts without it look inactive and do not work.
--
-- Where the power comes from is a backend:
--   standalone   built-in fuel generators and solar panels (this mod)
--   technic      vaultnet_power_technic: parts become Technic LV consumers
--   techage      vaultnet_power_techage: parts draw from a Techage power network
-- Setting `vaultnet_power_backend`: auto picks Technic, then Techage, then standalone.
--
-- Backends register with vaultnet.power.register_backend(name, def):
--   def.available() -> bool   (optional) whether the backend can be used
--   def.init()                (optional) called once at startup when selected
--   def.handler(pos, node, def) -> bool|nil   see vaultnet.register_power_handler

local modpath = core.get_modpath(core.get_current_modname())

local P = {backends = {}}
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

function P.register_backend(name, def)
	P.backends[name] = def
end

-- Built-in generators and solar panels.
dofile(modpath .. "/standalone.lua")

core.register_on_mods_loaded(function()
	if not vaultnet.require_power then return end
	local want = core.settings:get("vaultnet_power_backend") or "auto"
	local order = want == "auto" and {"technic", "techage", "standalone"} or {want, "standalone"}
	for _, name in ipairs(order) do
		local b = P.backends[name]
		if b and (not b.available or b.available()) then
			P.active = name
			if b.init then b.init() end
			vaultnet.register_power_handler(b.handler)
			core.log("action", "[vaultnet_power] power backend: " .. name)
			return
		end
		if name == want then
			core.log("warning", "[vaultnet_power] backend '" .. name .. "' is not available")
		end
	end
end)

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
