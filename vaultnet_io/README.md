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

## Importer and Exporter (`vaultnet_io:importer`, `vaultnet_io:exporter`)

- **Importer**: target inventory -> network. **Exporter**: network -> target inventory.
- Shaped after Refined Storage's Importer/Exporter: three stepped square plates on a
  cable-thin core. The Exporter's plates narrow towards the target (items leave through
  the tip), the Importer's widen towards it (items are taken in through the wide mouth).
  Built from connected nodeboxes with the cable textures (lightly tinted green for the
  Importer, orange for the Exporter; animated while the network is active). **Cable stubs
  only appear on sides that have a cable (or other device)**, like the cables themselves.
- Placed *against* a node: it points at that node. There is one node per direction
  (`vaultnet_io:importer_ny`, `_py`, `_nx`, `_px`, `_nz`, `_pz`, each with an `_active`
  twin); the `vaultnet_io:importer` / `exporter` item picks the right one.
- Right-click to configure: a non-interactive preview of the target's inventory
  layout (read from its `formspec` meta, or a generated grid when it has none); click
  an inventory list to use it, or tick it in the column on the right. A target with a
  single list is selected for you.
- Items per transfer: the Importer picks 1 / 2 / 4 / 8 / 16 / 32 / 64. The **Exporter takes an exact amount**: type
  any number from 1 to 9999 (more than a stack is moved a stack at a time until the number is met in
  that transfer). An item filter: drop items on the ghost
  slots; mode "only these" or "everything except these". Empty filter = everything.
- Devices act with their placer's rights on the core (`put` for Importer, `pull` for
  Exporter) and respect area protection on the target. Drives are never inserted.
- Wakes the target's node timer after exporting (so furnaces start).
- Settings: transfer interval, default amount.
- **Renamed:** the Importer used to be called the Inserter. Aliases turn old `vaultnet_io:inserter*` items and
  placed nodes into Importers (settings, filter and owner are kept), so nothing has to be swapped by hand.

Textures: `tools/gen_io_textures.py vaultnet_io` (needs Pillow).

## Requester and Supplier (`vaultnet_io:requester`, `vaultnet_io:supplier`)

Logistica-style, demand-driven devices. Same shape, placement, inventory-list preview and filter slots as the
Importer/Exporter (the Requester looks like an Exporter in blue, the Supplier like an Importer in violet).

- **Requester**: keeps the target stocked. Drop items on the slots and set an amount under each (default one
  stack). Each cycle it counts what the selected lists already hold and takes only the missing items from the
  network, up to the items-per-transfer amount.
- **Supplier**: the target's items (selected lists, filtered) become available to the network **without moving**:
  the network lists, counts and extracts them (so exporters, requesters, machines and the autocrafter can use
  them) but never stores into them. Logistica's passive supplier. It uses the owner's rights on the target.
