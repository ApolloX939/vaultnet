local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local S = core.settings

local TIERS = {
	{name = "Small", capacity = 1024, max_types = 8},
	{name = "Medium", capacity = 4096, max_types = 16},
	{name = "Large", capacity = 16384, max_types = 32},
	{name = "Huge", capacity = 65536, max_types = 0},
}

local function state_image(base)
	return function(state)
		return base .. "^vaultnet_drives_light" .. state .. ".png"
	end
end

for i, tier in ipairs(TIERS) do
	local capacity = tonumber(S:get("vaultnet_drives_capacity_" .. i)) or tier.capacity
	local max_types = tonumber(S:get("vaultnet_drives_max_types_" .. i)) or tier.max_types
	local base = "vaultnet_drives_drive" .. i .. ".png"

	core.register_craftitem(modname .. ":drive" .. i, {
		description = tier.name .. " VaultNet Drive",
		inventory_image = state_image(base)(1),
		wield_image = state_image(base)(1),
		stack_max = 1, -- contents live in the stack's meta
		groups = {vaultnet_drive = 1},
		vaultnet_drive = {
			capacity = capacity,
			max_types = max_types > 0 and max_types or nil,
			state_image = state_image(base),
		},
	})
end

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
