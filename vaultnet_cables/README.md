# vaultnet_cables

- `vaultnet_cables:cable`: thin dark-metal connected-nodebox cable. Connects visually to
  every `vaultnet_device`; networks connect adjacent devices on all 6 sides.
- `vaultnet_cables:cable_active`: animated twin, swapped in by `net:apply_active(true)`.
- Toggle cable (`toggle_on`, `toggle_on_active`, `toggle_off`): only registered when
  `vaultnet_require_power` is enabled. Right-click toggles; off isolates the cable and
  splits the network.

Recipes live in `recipes_mtg.lua` (Minetest Game, loaded when `default` is present).
Textures are generated placeholders: `tools/gen_cable_textures.py` (needs Pillow).
