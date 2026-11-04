-- VaultNet components: the craft items VaultNet devices are built from, so devices
-- cost more than a pile of ingots. Each has an own recipe from base-game items; when
-- Technic or Techage is installed some also get alternative recipes that accept those
-- mods' components (their own casing, logic unit, copper coil, battery, transformer,
-- chips). Neither mod is required.
--
-- Chain (all from Minetest Game items):
--   wire <- copper + paper         coil <- wire + mese fragment      casing <- steel
--   circuit <- wire + mese frag    processor <- circuits + gold + mese crystal
--   actuator <- coils + circuit    cell I..IV (storage) <- circuits/processors, glass, mese, diamond
--   transceiver <- coils + crystal resonator <- crystals + diamonds + processor
--   capacitor <- coils + coal      coupler <- coils + circuits + capacitor

local modpath = core.get_modpath(core.get_current_modname())

local COMPONENTS = {
	{"wire", "Insulated Wire"},
	{"coil", "Copper Coil"},
	{"casing", "Machine Casing"},
	{"circuit", "Circuit Board"},
	{"processor", "Logic Processor"},
	{"actuator", "Servo Actuator"},
	{"cell_1", "Storage Cell I"},
	{"cell_2", "Storage Cell II"},
	{"cell_3", "Storage Cell III"},
	{"cell_4", "Storage Cell IV"},
	{"transceiver", "Radio Transceiver"},
	{"resonator", "Resonance Crystal"},
	{"capacitor", "Power Capacitor"},
	{"coupler", "Power Coupler"},
}

for _, c in ipairs(COMPONENTS) do
	core.register_craftitem("vaultnet_components:" .. c[1], {
		description = "VaultNet " .. c[2],
		inventory_image = "vaultnet_components_" .. c[1] .. ".png",
	})
end

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
