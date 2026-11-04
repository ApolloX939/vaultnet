# vaultnet_machines

Optional. Network-fed processing machines in the style of Technic's: **Smelter**, **Grinder**,
**Compressor** and **Alloy Furnace**.

- Like the autocrafter, a machine does ONE job. Right-click and drop the input item (the Alloy Furnace
  takes two) on its ghost slot(s); the formspec shows what it will make and how long it takes. It takes the
  inputs out of the network, works for the recipe time, and stores the results back (output the network
  cannot take waits in a buffer you can empty by hand). It never touches stock you did not point it at.
- Recipes: the **Smelter** uses the engine's cooking recipes. The others use a registry
  (`vaultnet_machines.register_recipe(type, {input = {...}, output = {...}, time = s})`, types `grinder`,
  `compressor`, `alloy`): Minetest Game basics (ores give 2 lumps, sand into sandstone, copper + tin into bronze)
  plus the grinding, compressing and alloy recipes of Technic when it is installed.
- With `vaultnet_require_power` on a machine draws 1 unit/s idle and 10-14 units/s while working (see
  `vaultnet_power`), so batteries help. It acts with its placer's rights on the core.
- Settings: `vaultnet_machines_enabled`, `vaultnet_machines_speed`, `vaultnet_machines_import_technic`.

Textures: `tools/gen_machine_textures.py vaultnet_machines` (needs Pillow).
