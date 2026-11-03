-- Power hook. The API itself knows nothing about power systems; vaultnet_power
-- (and its Technic/Techage adapters) register handlers here.

vaultnet.require_power = core.settings:get_bool("vaultnet_require_power", false)

local handlers = {}

-- fn(pos, node, def) -> true (powered) | false (unpowered) | nil (no opinion)
function vaultnet.register_power_handler(fn)
	handlers[#handlers + 1] = fn
end

-- Always true when `vaultnet_require_power` is off. When it is on, a part is
-- powered only if some handler says so.
function vaultnet.is_powered(pos)
	if not vaultnet.require_power then return true end
	local def, node = vaultnet.get_device(pos)
	if not def then return false end
	for _, fn in ipairs(handlers) do
		local r = fn(pos, node, def)
		if r ~= nil then return r and true or false end
	end
	return false
end
