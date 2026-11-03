# vaultnet_drives

Four drive tiers (`vaultnet_drives:drive1` .. `drive4`: Small, Medium, Large, Huge).

- Contents are stored in the drive item's own meta by `vaultnet.drive` (vaultnet_api),
  keyed by the full ItemStack string, so wear and all meta come back unchanged.
  A drive keeps its contents when carried; its description shows `used / capacity`.
- Fullness light: the inventory/wield image gets a green -> red light overlay
  (5 states) that is refreshed whenever the contents change.
- Drives cannot be stored inside drives.
- Capacity and max distinct item kinds per tier are settings (`settingtypes.txt`).
- Drives only work inside a drive host (the drive bay, still TODO).

Recipes: `recipes_mtg.lua` (Minetest Game). Textures are generated placeholders:
`tools/gen_drive_textures.py` (needs Pillow).
