# vaultnet_autocrafter

Optional. Crafts one fixed recipe from items in the network and stores the result back.

- Right-click, then drop items on the 3x3 grid to set the recipe (ghost slots: only the
  item name is recorded; click a slot to clear it). The result is previewed. Shaped and
  shapeless recipes both work, as long as they fit the 3x3 grid (the engine's own craft
  lookup is used, so groups and replacements behave as in normal crafting).
- Each craft takes one of each ingredient from the network (any stored variant of the
  item, metadata and all), then inserts the output and any replacement items. If the
  network is missing something nothing is taken; the status line says what.
- Acts with its placer's rights on the core: it needs `pull` and `put`.
- Output the network cannot take is parked in a 9-slot buffer (shown in the formspec, and
  you can take it out) and the crafter pauses until the buffer is empty. It can only be
  dug when the buffer is empty.
- Static front while idle, animated while the network is active.
- Settings: `vaultnet_autocrafter_enabled` (default on; off registers nothing),
  `vaultnet_autocrafter_test_recipe` (adds water bucket + sand -> 2 clay lumps with the empty bucket as a
  replacement, for testing; Minetest Game has no such recipe) and
  `vaultnet_autocrafter_interval` (seconds per craft).

Textures: `tools/gen_autocrafter_textures.py vaultnet_autocrafter` (needs Pillow).
