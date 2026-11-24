-- VaultNet ships its recipes only for Minetest Game (recipes_mtg.lua, loaded when `default` exists).
-- On Skyblock: Zero there is no `default`, so this mod, which loads after every VaultNet sub-mod,
-- asks vaultnet_api to register those same recipes with the ingredients translated to SBZ items.
-- The translation table lives in vaultnet_api/src/materials.lua (vaultnet.materials.sbz).

if vaultnet.game() ~= "sbz" then return end

-- "Where from": each VaultNet sub-mod shows up as "Vaultnet (<part>)" in item tooltips / the crafting
-- guide (the same hook Camps and Cogwork use). This is the only place it is registered.
if sbz_api and sbz_api.modname then
	for name, part in pairs({
		vaultnet_api = "API",
		vaultnet_components = "Components",
		vaultnet_core = "Core",
		vaultnet_cables = "Cables",
		vaultnet_drives = "Drives",
		vaultnet_io = "I/O",
		vaultnet_power = "Power",
		vaultnet_machines = "Machines",
		vaultnet_autocrafter = "Autocrafter",
		vaultnet_wireless = "Wireless",
		vaultnet_power_technic = "Technic Power",
		vaultnet_power_techage = "Techage Power",
		vaultnet_sbz = "Skyblock: Zero",
	}) do
		sbz_api.modname[name] = "Vaultnet (" .. part .. ")"
	end
end

vaultnet.register_recipes("sbz", {
	"vaultnet_components", "vaultnet_core", "vaultnet_cables", "vaultnet_drives", "vaultnet_io",
	"vaultnet_power", "vaultnet_machines", "vaultnet_autocrafter", "vaultnet_wireless",
})
