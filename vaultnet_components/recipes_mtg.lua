-- Minetest Game recipes for the components, plus optional alternatives that use
-- Technic's or Techage's own components.

local S, C, G, P = "default:steel_ingot", "default:copper_ingot", "default:glass", "default:paper"
local F, CR, D = "default:mese_crystal_fragment", "default:mese_crystal", "default:diamond"
local GOLD, MB, DB = "default:gold_ingot", "default:mese", "default:diamondblock"
local V = function(n) return "vaultnet_components:" .. n end

local function shaped(out, recipe) core.register_craft({output = V(out), recipe = recipe}) end
local function shaped_n(out, n, recipe) core.register_craft({output = V(out) .. " " .. n, recipe = recipe}) end

shaped_n("wire", 6, {{P, P, P}, {C, C, C}})
shaped("coil", {{V"wire", V"wire", V"wire"}, {V"wire", F, V"wire"}, {V"wire", V"wire", V"wire"}})
shaped("casing", {{S, S, S}, {S, "", S}, {S, S, S}})
shaped("circuit", {{V"wire", F, V"wire"}, {F, C, F}, {V"wire", F, V"wire"}})
shaped("processor", {{V"circuit", GOLD, V"circuit"}, {GOLD, CR, GOLD}, {V"circuit", GOLD, V"circuit"}})
shaped("actuator", {{S, V"coil", S}, {V"coil", V"circuit", V"coil"}, {S, S, S}})

shaped("cell_1", {{V"circuit", G, V"circuit"}, {S, F, S}, {S, S, S}})
shaped("cell_2", {{V"cell_1", CR, V"cell_1"}, {V"circuit", V"circuit", V"circuit"}, {S, S, S}})
shaped("cell_3", {{V"cell_2", D, V"cell_2"}, {V"processor", CR, V"processor"}, {S, S, S}})
shaped("cell_4", {{V"cell_3", DB, V"cell_3"}, {V"processor", MB, V"processor"}, {S, S, S}})

shaped("transceiver", {{V"coil", CR, V"coil"}, {S, V"circuit", S}, {S, V"wire", S}})
shaped("resonator", {{CR, D, CR}, {D, V"processor", D}, {CR, D, CR}})
shaped("capacitor", {{S, V"coil", S}, {C, "default:coal_lump", C}, {S, V"coil", S}})
shaped("coupler", {{V"coil", S, V"coil"}, {V"circuit", V"capacitor", V"circuit"}, {S, S, S}})

-- Technic's own components can stand in for the first steps ---------------------------------
if core.get_modpath("technic") then
	local function alt(out, n, ...)
		core.register_craft({type = "shapeless", output = V(out) .. " " .. n, recipe = {...}})
	end
	alt("wire", 2, "technic:lv_cable")
	alt("coil", 1, "technic:copper_coil")
	alt("casing", 1, "technic:machine_casing")
	alt("circuit", 2, "technic:control_logic_unit")
	alt("processor", 1, "technic:control_logic_unit", "technic:control_logic_unit", GOLD)
	alt("capacitor", 1, "technic:battery")
	alt("coupler", 1, "technic:lv_transformer")
end

-- Techage's too ------------------------------------------------------------------------------
if core.get_modpath("techage") then
	local A = "techage:aluminum"
	shaped("casing", {{A, A, A}, {A, "", A}, {A, A, A}})
	core.register_craft({type = "shapeless", output = V"circuit" .. " 2", recipe = {"techage:ta4_ramchip"}})
	core.register_craft({type = "shapeless", output = V"transceiver", recipe = {"techage:ta4_wlanchip"}})
	core.register_craft({type = "shapeless", output = V"processor", recipe = {"techage:ta5_controlunit"}})
end
