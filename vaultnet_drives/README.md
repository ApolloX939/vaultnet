# vaultnet_drives

Ten drive tiers (`vaultnet_drives:drive1` .. `drive10`): Tiny 1k, Mini 2k, Small 4k, Medium 8k, Large 16k, Big 32k, Huge 64k, Giant 256k, Massive 1M, Colossal 4M items (defaults).

- Contents are stored in the drive item's own meta by `vaultnet.drive` (vaultnet_api),
  keyed by the full ItemStack string, so wear and all meta come back unchanged.
  A drive keeps its contents when carried; its tooltip shows `used / capacity items (percent)`, e.g. `256 / 1,024 items (25%)`, also on a new empty drive.
- Fullness light: the inventory/wield image gets a green -> red light overlay
  (5 states) that is refreshed whenever the contents change.
- Drives cannot be stored inside drives.
- A drive with contents carries the `no_emc` meta flag (kept in step by the drive code, repaired for older drives when
  their owner joins or the bay refreshes), so EMC mods do not convert it and destroy its contents.
- Capacity per tier is a setting (`settingtypes.txt`). There is no limit on distinct item kinds.
- Drives only work inside a drive host, i.e. the drive bay.

## Drive bay (`vaultnet_drives:bay`)

Modelled on Refined Storage's disk drive.

- 3D mesh block with 2 columns x 4 rows of recessed slots (8 drives, fixed). Right-click for
  the inventory; only drives are accepted and slots respect protection. It must be emptied
  before it can be dug (blasts drop the drives). Role `bay`: provides the slots the network
  stores items in.
- Each inserted drive shows as a small flat disk sticking out 1/16 of a node (a mesh
  entity), tinted by tier, with its own LED (painted onto a reserved texel of the disk texture, since the engine does not reliably give separate .obj materials separate textures): green -> red (5 states) by fullness. Refreshed
  on insert/remove and whenever the network stores or extracts items. Entities are not
  saved: an LBM restores them on load and an ABM repairs missing ones. If the disks look
  edge-on, set `YAW_OFFSET` in `bay.lua`.
- `bay_active` is swapped in while the network is active: the slot interiors pulse blue.
- Drive items use an RS-style disk icon with the same LED (set through item meta).

Models and textures are generated: `tools/gen_drive_textures.py vaultnet_drives` (needs Pillow).
