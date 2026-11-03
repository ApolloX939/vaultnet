# vaultnet_io

Ways in and out of a network.

## Terminal (`vaultnet_io:terminal`)

Right-click to open. Needs `put` or `pull` access on the network's core.

- Browse everything stored, with search and paging. Hover an item for its full
  name and count.
- **Take**: click an item; the dropdown picks 1, 10 or a full stack. Needs `pull`.
  Items come back exactly as stored (wear and metadata intact).
- **Insert**: drop items into the Insert slots (or shift-click from your inventory);
  they are stored at once, and anything that does not fit stays in the slot. Needs
  `put`. Drives can not be stored. The terminal can only be dug when the slots are empty.
- Blue scrolling screen while the network is active.

## Inserter and Exporter (`vaultnet_io:inserter`, `vaultnet_io:exporter`)

- **Inserter**: target inventory -> network. **Exporter**: network -> target inventory.
- Shaped after Refined Storage's Importer/Exporter: three stepped square plates on a
  cable-thin core. The Exporter's plates narrow towards the target (items leave through
  the tip), the Inserter's widen towards it (items are taken in through the wide mouth).
  Built from connected nodeboxes with the cable textures (lightly tinted green for the
  Inserter, orange for the Exporter; animated while the network is active). **Cable stubs
  only appear on sides that have a cable (or other device)**, like the cables themselves.
- Placed *against* a node: it points at that node. There is one node per direction
  (`vaultnet_io:inserter_ny`, `_py`, `_nx`, `_px`, `_nz`, `_pz`, each with an `_active`
  twin); the `vaultnet_io:inserter` / `exporter` item picks the right one.
- Right-click to configure: a non-interactive preview of the target's inventory
  layout (read from its `formspec` meta, or a generated grid when it has none); click
  an inventory list to use it, or tick it in the column on the right. A target with a
  single list is selected for you.
- Items per transfer (1 / 4 / 16 / 64), and an item filter: drop items on the ghost
  slots; mode "only these" or "everything except these". Empty filter = everything.
- Devices act with their placer's rights on the core (`put` for Inserter, `pull` for
  Exporter) and respect area protection on the target. Drives are never inserted.
- Wakes the target's node timer after exporting (so furnaces start).
- Settings: transfer interval, default amount.

Textures: `tools/gen_io_textures.py vaultnet_io` (needs Pillow).
