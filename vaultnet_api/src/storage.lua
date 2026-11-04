-- Network-wide item storage on top of drives.
--
-- A device def with `get_drive_slots(pos)` provides drive slots: an array of
-- {get = function() -> ItemStack, set = function(ItemStack)}. Use
-- vaultnet.inv_slots(pos, listname) for slots backed by a node inventory.
-- After changing drives, `on_drives_changed(pos)` is called on that device so
-- it can refresh visuals (fullness lights).
--
-- Operations take opts = {actor = playername}. With an actor the core's access
-- list is checked ("put" / "pull"); without one (automation) it is not.
-- All return a trailing error string on failure instead of raising.

local Network = vaultnet.Network
local drive = vaultnet.drive

function vaultnet.inv_slots(pos, listname)
	local inv = core.get_meta(pos):get_inventory()
	local slots = {}
	for i = 1, inv:get_size(listname) do
		slots[i] = {
			get = function() return inv:get_stack(listname, i) end,
			set = function(stack) inv:set_stack(listname, i, stack) end,
		}
	end
	return slots
end

-- "ok" or (false, reason): "no_core" | "multiple_cores" | "unpowered" | "denied"
function Network:check(opts, perm)
	local status = self:status()
	if status ~= "ok" then return false, status end
	local actor = opts and opts.actor
	if actor and not vaultnet.access.can(self.cores[1], actor, perm) then
		return false, "denied"
	end
	return true
end

-- Calls fn(drive_stack, slot, host_pos) for every drive in the network. If fn
-- returns true the (mutated) drive stack is written back and the host marked
-- changed. If it returns "stop" it is written back and iteration ends.
local function each_drive(net, fn)
	local changed, order = {}, {}
	local stop = false
	for _, host in ipairs(net.drive_hosts) do
		local def = vaultnet.get_def(core.get_node(host).name)
		if def and def.get_drive_slots then
			for _, slot in ipairs(def.get_drive_slots(host)) do
				local stack = slot.get()
				if drive.is_drive(stack) then
					local r = fn(stack, slot, host)
					if r then
						slot.set(stack)
						local h = vaultnet.pos_hash(host)
						if not changed[h] then
							changed[h] = true
							order[#order + 1] = host
						end
						if r == "stop" then stop = true; break end
					end
				end
			end
		end
		if stop then break end
	end
	for _, host in ipairs(order) do
		local def = vaultnet.get_def(core.get_node(host).name)
		if def and def.on_drives_changed then def.on_drives_changed(host) end
	end
end

-- Store a stack. Returns (leftover ItemStack, err). Drives cannot be stored.
function Network:insert(stack, opts)
	stack = ItemStack(stack)
	local ok, err = self:check(opts, "put")
	if not ok then return stack, err end
	if stack:is_empty() then return stack end
	if drive.is_drive(stack) then return stack, "not_storable" end

	local key = vaultnet.item_key(stack)
	for pass = 1, 2 do -- pass 1: drives already holding this kind
		each_drive(self, function(d)
			if stack:is_empty() then return "stop" end
			if pass == 1 and drive.count(d, key) == 0 then return false end
			local n = drive.add(d, stack)
			if n == 0 then return false end
			stack:set_count(stack:get_count() - n)
			return stack:is_empty() and "stop" or true
		end)
		if stack:is_empty() then break end
	end
	return stack
end

-- Take up to `count` (and at most one full stack) of the exact item `key`.
-- Returns (ItemStack, err); the stack is empty when nothing was available.
function Network:extract_key(key, count, opts)
	local ok, err = self:check(opts, "pull")
	if not ok then return ItemStack(), err end
	local want = math.min(count, vaultnet.key_stack_max(key))
	local got = 0
	each_drive(self, function(d)
		local n = drive.take(d, key, want - got)
		if n == 0 then return false end
		got = got + n
		return got >= want and "stop" or true
	end)
	return vaultnet.key_to_stack(key, got)
end

-- Like extract_key but matches the first stored variant with this item name.
function Network:extract_name(name, count, opts)
	local ok, err = self:check(opts, "pull")
	if not ok then return ItemStack(), err end
	for _, entry in ipairs(self:list()) do
		if entry.name == name then
			return self:extract_key(entry.key, count, opts)
		end
	end
	return ItemStack()
end

-- Aggregated contents: array of {key, name, count} sorted by name, then key.
-- (Not access-checked: UIs decide what to show.)
function Network:list()
	local totals = {}
	each_drive(self, function(d)
		for key, n in pairs(drive.contents(d)) do
			totals[key] = (totals[key] or 0) + n
		end
		return false
	end)
	local out = {}
	for key, n in pairs(totals) do
		out[#out + 1] = {key = key, name = vaultnet.key_name(key), count = n}
	end
	table.sort(out, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		return a.key < b.key
	end)
	return out
end

function Network:count_key(key)
	local total = 0
	each_drive(self, function(d)
		total = total + drive.count(d, key)
		return false
	end)
	return total
end

-- Returns used, capacity over every drive.
function Network:capacity()
	local used, cap = 0, 0
	each_drive(self, function(d)
		local info = drive.info(d)
		used, cap = used + info.used, cap + info.capacity
		return false
	end)
	return used, cap
end
