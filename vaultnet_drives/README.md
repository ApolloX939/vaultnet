# vaultnet_drives

Ten drive tiers (`vaultnet_drives:drive1` .. `drive10`): Tiny 1k, Mini 2k, Small 4k, Medium 8k, Large 16k, Big 32k, Huge 64k, Giant 256k, Massive 1M, Colossal 4M items (defaults).

- Contents are stored in the drive item's own meta by `vaultnet.drive` (vaultnet_api),
  keyed by the full ItemStack string, so wear and all meta come back unchanged.
  A drive keeps its contents when carried; its description shows `used / capacity`.
- Fullness light: the inventory/wield image gets a green -> red light overlay
  (5 states) that is refreshed whenever the contents change.
- Drives cannot be stored inside drives.
- Capacity per tier is a setting (`settingtypes.txt`). There is no limit on distinct item kinds.
- Drives only work inside a drive host, i.e. the drive bay.

## Drive bay (`vaultnet_drives:bay`)

- Holds 8 drives (fixed). Right-click for the inventory; only drives are accepted and
  slots respect protection. It must be emptied before it can be dug (blasts drop the
  drives). Role `bay`: provides the slots the network stores items in.
- Each inserted drive is drawn on the front face (`upright_sprite` entity) with its
  fullness light, and refreshed on insert/remove and whenever the network stores or
  extracts items. Entities are not saved: an LBM restores them on load and an ABM
  repairs missing ones. If the sprites look edge-on, set `YAW_OFFSET` in `bay.lua`.
- `bay_active` is the lit variant swapped in while the network is active.

Recipes: `recipes_mtg.lua` (Minetest Game). Textures are generated placeholders:
`tools/gen_drive_textures.py` (needs Pillow).
