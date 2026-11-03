-- Network discovery. Every device connects to every directly adjacent device
-- (6 directions, no diagonals) unless one side does not conduct or refuses the
-- connection. Extra non-adjacent edges (wireless relays) come from link
-- providers.
--
-- Device def hooks (all optional, see README.md):
--   conducts(pos, node)          -> false isolates this node (toggle cable off)
--   can_connect(pos, node, dir)  -> false refuses the face in direction `dir`
--   active_variant / inactive_variant (node names) used by Network:apply_active

local Network = {}
Network.__index = Network
vaultnet.Network = Network

local MAX_NODES = tonumber(core.settings:get("vaultnet_max_network_nodes")) or 4096
local CACHE_TTL = 30 -- seconds of game time before a cached network is rebuilt

local cache = {} -- node hash -> network
local next_id = 1
local link_providers = {}

-- fn(pos, node, def) -> array of positions linked to pos (e.g. the partner
-- relay). Call vaultnet.notify_changed on both ends whenever a link changes.
function vaultnet.register_link_provider(fn)
	link_providers[#link_providers + 1] = fn
end

local function conducts(pos, node, def)
	return not def.conducts or def.conducts(pos, node) ~= false
end

local function can_connect(def, pos, node, dir)
	return not def.can_connect or def.can_connect(pos, node, dir) ~= false
end

local function drop(net)
	for h in pairs(net.nodes) do
		if cache[h] == net then cache[h] = nil end
	end
end

function vaultnet.notify_changed(pos)
	local function invalidate(p)
		local net = cache[vaultnet.pos_hash(p)]
		if net then drop(net) end
	end
	invalidate(pos)
	for _, d in ipairs(vaultnet.DIRS) do
		invalidate({x = pos.x + d.x, y = pos.y + d.y, z = pos.z + d.z})
	end
	-- re-evaluate active/inactive looks shortly after the change settles
	if vaultnet.schedule_refresh then vaultnet.schedule_refresh(pos) end
end

local function add_member(net, pos, def)
	net.nodes[vaultnet.pos_hash(pos)] = vaultnet.copy_pos(pos)
	net.count = net.count + 1
	local role = def.role or "device"
	local list = net.roles[role]
	if not list then list = {}; net.roles[role] = list end
	list[#list + 1] = vaultnet.copy_pos(pos)
	if role == "core" then net.cores[#net.cores + 1] = vaultnet.copy_pos(pos) end
	if def.get_drive_slots then
		net.drive_hosts[#net.drive_hosts + 1] = vaultnet.copy_pos(pos)
	end
end

local function build(start)
	local snode = core.get_node_or_nil(start)
	if not snode or not vaultnet.get_def(snode.name) then return nil end

	local net = setmetatable({
		id = next_id,
		nodes = {},      -- hash -> pos
		count = 0,
		roles = {},      -- role -> array of pos
		cores = {},      -- array of pos
		drive_hosts = {},-- positions of nodes providing drive slots
		incomplete = false, -- touched unloaded map area
		truncated = false,  -- hit vaultnet_max_network_nodes
		created = core.get_gametime(),
	}, Network)
	next_id = next_id + 1

	local seen = {[vaultnet.pos_hash(start)] = true}
	local queue = {vaultnet.copy_pos(start)}
	local head = 1

	local function push(q)
		local h = vaultnet.pos_hash(q)
		if not seen[h] then
			seen[h] = true
			queue[#queue + 1] = vaultnet.copy_pos(q)
		end
	end

	while head <= #queue do
		local p = queue[head]
		head = head + 1
		local node = core.get_node_or_nil(p)
		if not node then
			net.incomplete = true
		else
			local def = vaultnet.get_def(node.name)
			if def then
				add_member(net, p, def)
				if net.count >= MAX_NODES then
					net.truncated = true
					break
				end
				if conducts(p, node, def) then
					for _, d in ipairs(vaultnet.DIRS) do
						local q = {x = p.x + d.x, y = p.y + d.y, z = p.z + d.z}
						if not seen[vaultnet.pos_hash(q)] then
							local qnode = core.get_node_or_nil(q)
							if not qnode then
								net.incomplete = true
							else
								local qdef = vaultnet.get_def(qnode.name)
								local back = {x = -d.x, y = -d.y, z = -d.z}
								if qdef and conducts(q, qnode, qdef)
										and can_connect(def, p, node, d)
										and can_connect(qdef, q, qnode, back) then
									push(q)
								end
							end
						end
					end
					for _, provider in ipairs(link_providers) do
						for _, q in ipairs(provider(p, node, def) or {}) do
							push(q)
						end
					end
				end
			end
		end
	end

	if not net.incomplete then
		for h in pairs(net.nodes) do cache[h] = net end
	end
	return net
end

-- Network containing `pos`, or nil when pos is not a device / not loaded.
function vaultnet.get_network(pos)
	local net = cache[vaultnet.pos_hash(pos)]
	if net and core.get_gametime() - net.created > CACHE_TTL then
		drop(net)
		net = nil
	end
	return net or build(pos)
end

function Network:has(pos)
	return self.nodes[vaultnet.pos_hash(pos)] ~= nil
end

function Network:get_positions_by_role(role)
	return self.roles[role] or {}
end

function Network:get_core()
	return self.cores[1]
end

-- "ok" | "no_core" | "multiple_cores" | "unpowered"
function Network:status()
	if #self.cores == 0 then return "no_core" end
	if #self.cores > 1 then return "multiple_cores" end
	if not vaultnet.is_powered(self.cores[1]) then return "unpowered" end
	return "ok"
end

function Network:is_active()
	return self:status() == "ok"
end

-- Swap every device to its active/inactive variant (animated textures).
-- Does not change topology, so no cache invalidation is needed.
function Network:apply_active(state)
	for _, pos in pairs(self.nodes) do
		local node = core.get_node_or_nil(pos)
		local def = node and vaultnet.get_def(node.name)
		if def then
			-- (not `state and a or b`: that falls through to b when a is nil,
			-- which flipped already-active nodes back to inactive)
			local target
			if state then
				target = def.active_variant
			else
				target = def.inactive_variant
			end
			if target and target ~= node.name then
				node.name = target
				core.swap_node(pos, node)
			end
		end
	end
end
