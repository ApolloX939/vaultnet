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

Inserter and Exporter are still TODO. Textures: `tools/gen_io_textures.py`.
