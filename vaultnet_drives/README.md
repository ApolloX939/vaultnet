# vaultnet_drives

Ten drive tiers (`vaultnet_drives:drive1` .. `drive10`): Tiny 1k, Mini 2k, Small 4k, Medium 8k, Large 16k, Big 32k, Huge 64k, Giant 256k, Massive 1M, Colossal 4M items (defaults).

- Contents are stored in the drive item's own meta by `vaultnet.drive` (vaultnet_api),
  keyed by the full ItemStack string, so wear and all meta come back unchanged.
  A drive keeps its contents when carried; its description shows `used / capacity`.
- Fullness light: the inventory/wield image gets a green -> red light overlay
  (5 states) that is refreshed whenever the contents change.
- Drives cannot be stored inside drives.
- Capacity per tier is a setting (`settingtypes.txt`). There is no limit on distinct item kinds.
- Drives only work inside a drive host (the drive bay, still TODO).

Recipes: `recipes_mtg.lua` (Minetest Game). Textures are generated placeholders:
`tools/gen_drive_textures.py` (needs Pillow).
