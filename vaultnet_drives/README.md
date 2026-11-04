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

Modelled on Refined Storage's disk drive.

- 3D mesh block with 2 columns x 4 rows of recessed slots (8 drives, fixed). Right-click for
  the inventory; only drives are accepted and slots respect protection. It must be emptied
  before it can be dug (blasts drop the drives). Role `bay`: provides the slots the network
  stores items in.
- Each inserted drive shows as a small flat disk sticking out 1/16 of a node (a mesh
  entity), tinted by tier, with its own LED: green -> red (5 states) by fullness. Refreshed
  on insert/remove and whenever the network stores or extracts items. Entities are not
  saved: an LBM restores them on load and an ABM repairs missing ones. If the disks look
  edge-on, set `YAW_OFFSET` in `bay.lua`.
- `bay_active` is swapped in while the network is active: the slot interiors pulse blue.
- Drive items use an RS-style disk icon with the same LED (set through item meta).

Models and textures are generated: `tools/gen_drive_textures.py vaultnet_drives` (needs Pillow).
