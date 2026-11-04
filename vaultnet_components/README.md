# vaultnet_components

The craft items every VaultNet device is built from. All recipes start from Minetest Game items, so no
other mod is needed.

| Component | Recipe (own) | Used for |
|---|---|---|
| Insulated Wire | 3 paper + 3 copper -> 6 | cables, coils, circuits |
| Copper Coil | 8 wire around a mese fragment | actuators, capacitors, transceivers |
| Machine Casing | 8 steel ingots in a ring | devices |
| Circuit Board | 4 wire, 4 mese fragments, 1 copper | almost everything |
| Logic Processor | 4 circuits, 4 gold, 1 mese crystal | core, cells, top-tier devices |
| Servo Actuator | 4 steel, 3 coils, 1 circuit | bay, Inserter/Exporter, machines |
| Storage Cell I-IV | circuits, then lower cells, diamonds, processors, blocks | drives |
| Radio Transceiver | 2 coils, crystal, circuit | wireless relay |
| Resonance Crystal | 4 mese crystals, 4 diamonds, 1 processor | core |
| Power Capacitor | 2 coils, coal, copper, steel | batteries, couplers |
| Power Coupler | 2 coils, 2 circuits, a capacitor | generator, solar, power adapters |

**Optional alternatives** (only registered when the mod is installed): with **Technic**, `technic:lv_cable`,
`copper_coil`, `machine_casing`, `control_logic_unit`, `battery` and `lv_transformer` can be turned into the matching
components; with **Techage**, aluminum makes casings, and `ta4_ramchip`, `ta4_wlanchip` and `ta5_controlunit` make
circuits, transceivers and processors.

Textures: `tools/gen_component_textures.py vaultnet_components` (needs Pillow).

## EMC

With the [EMC mod](https://codeberg.org/F3mboyPhoenix/emc) installed, every VaultNet item (components, devices, drives,
batteries, machines, adapters) gets an EMC value from its crafting recipe. Two things are handled so those values
are stable (`emc.lua`, loaded only when that mod is present):

- Components are priced from their **own** recipes, never from a Technic/Techage alternative (those would otherwise
  win or lose depending on solver order; e.g. a capacitor from a Technic battery would cost 13x less).
- Base items the recipes use (steel, bronze, ...) get their usual value if a world leaves them unpriced (Techage
  worlds, where the EMC mod does not know Techage's iron chain), so no VaultNet item is left without a value.

Not handled: the EMC mod prices an item by name only, so a drive full of items or a charged battery is worth just the
empty drive/battery, and transmuting it destroys the contents. `tools/run_tests.sh --emc` (with `EMC_DIR` set to a clone
of the EMC mod) checks all of this.
