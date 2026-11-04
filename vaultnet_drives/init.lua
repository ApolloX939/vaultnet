local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local S = core.settings

local TIERS = {
	{name = "Tiny", capacity = 1024},
	{name = "Mini", capacity = 2048},
	{name = "Small", capacity = 4096},
	{name = "Medium", capacity = 8192},
	{name = "Large", capacity = 16384},
	{name = "Big", capacity = 32768},
	{name = "Huge", capacity = 65536},
	{name = "Giant", capacity = 262144},
	{name = "Massive", capacity = 1048576},
	{name = "Colossal", capacity = 4194304},
}

local function state_image(base)
	return function(state)
		return base .. "^vaultnet_drives_light" .. state .. ".png"
	end
end

for i, tier in ipairs(TIERS) do
	local capacity = tonumber(S:get("vaultnet_drives_capacity_" .. i)) or tier.capacity
	local base = "vaultnet_drives_drive" .. i .. ".png"

	core.register_craftitem(modname .. ":drive" .. i, {
		description = tier.name .. " VaultNet Drive",
		inventory_image = state_image(base)(1),
		wield_image = state_image(base)(1),
		stack_max = 1, -- contents live in the stack's meta
		groups = {vaultnet_drive = 1},
		vaultnet_drive = {
			capacity = capacity,
			state_image = state_image(base),
			disk_texture = "vaultnet_drives_disk" .. i .. ".png", -- the disk shown in a bay
		},
	})
end

-- Drives made before the no_emc flag existed get it when their owner joins.
core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	for listname, list in pairs(inv:get_lists()) do
		for i, stack in ipairs(list) do
			if not stack:is_empty() and vaultnet.drive.sync_flags(stack) then
				inv:set_stack(listname, i, stack)
			end
		end
	end
end)

dofile(modpath .. "/bay.lua")

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
