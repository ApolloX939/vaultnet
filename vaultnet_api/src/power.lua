-- Power hook. The API itself knows nothing about power systems; vaultnet_power
-- (and its Technic/Techage adapters) provide the backend.
--
-- A device that uses power says so in its `vaultnet` def (`consumes_power = true`).
-- How much it uses is decided by vaultnet_power: `vaultnet.power_use_by_role[role]`
-- (units per second), unless the def sets `power_use`. Cables and power sources
-- do not consume power.

vaultnet.require_power = core.settings:get_bool("vaultnet_require_power", false)

vaultnet.power_use_by_role = {}

-- Units per second a device def draws (0 when it draws none).
function vaultnet.power_use(def)
	if not def or not def.consumes_power then return 0 end
	return def.power_use or vaultnet.power_use_by_role[def.role] or 0
end

local handlers = {}

-- fn(pos, node, def) -> true (powered) | false (unpowered) | nil (no opinion)
function vaultnet.register_power_handler(fn)
	handlers[#handlers + 1] = fn
end

-- Always true when `vaultnet_require_power` is off, and for devices that use no
-- power (cables, sources). Otherwise a part is powered only if some handler says
-- so; with no handler (vaultnet_power not installed) nothing is powered.
function vaultnet.is_powered(pos)
	if not vaultnet.require_power then return true end
	local def, node = vaultnet.get_device(pos)
	if not def then return false end
	if not def.consumes_power then return true end
	for _, fn in ipairs(handlers) do
		local r = fn(pos, node, def)
		if r ~= nil then return r and true or false end
	end
	return false
end
