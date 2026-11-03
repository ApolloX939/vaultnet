-- Event-driven active/inactive looks. After any topology change the affected
-- networks (the changed node and its 6 neighbours) are re-evaluated a moment
-- later and every device is swapped to its active or inactive variant.
-- State changes that are not topology changes (power, core removal handled by
-- topology, ...) should call vaultnet.schedule_refresh(pos) themselves.

local pending, scheduled = {}, false

local function flush()
	scheduled = false
	local list = pending
	pending = {}
	local done = {}
	for _, pos in ipairs(list) do
		local net = vaultnet.get_network(pos)
		if net and not done[net] then
			done[net] = true
			net:apply_active(net:status() == "ok")
		end
	end
end

function vaultnet.schedule_refresh(pos)
	pending[#pending + 1] = vaultnet.copy_pos(pos)
	for _, d in ipairs(vaultnet.DIRS) do
		pending[#pending + 1] = {x = pos.x + d.x, y = pos.y + d.y, z = pos.z + d.z}
	end
	if not scheduled then
		scheduled = true
		core.after(0.2, flush)
	end
end
