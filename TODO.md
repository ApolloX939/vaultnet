# TODO: vaultnet (Mass Item Storage Modpack for Luanti)

## Ground Rules
- [ ] Everything is implemented inside the modpack, with no extra mods required (adapters for other mods stay optional)
- [ ] Structure it as a modpack: sub mods for most features, plus sub mods for cross-cutting concepts
- [ ] Preserve all item metadata, so nothing can tell an item was stored and pulled back out (full ItemStack serialization: meta, wear, count)
- [ ] Commit by section. Do NOT push without asking: the owner reviews commits first (remote is established)
- [x] Set up the git repo and remote

## Game Support
- [ ] Minetest Game (first target; recipes in a per-game file, loaded only if `default` is present)
- [ ] Mineclonia (later)
- [ ] VoxeLibre (later)
- [ ] Hades Revisited (later)
- [ ] Skyblock Zero (later)

## Modpack Layout (sub mods)
- [x] `vaultnet_api`: shared network graph, item storage API, metadata-safe serialization
- [x] `vaultnet_cables`: cables, active cables, toggle cable
- [x] `vaultnet_drives`: drives and the drive bay
- [x] `vaultnet_core`: central node, access control formspec
- [ ] `vaultnet_io`: Inserter and Exporter (terminal done, Inserter/Exporter TODO)
- [ ] `vaultnet_autocrafter`: autocrafter (opt-in)
- [ ] `vaultnet_wireless`: wireless relay (opt-in, forceloads both ends)
- [ ] `vaultnet_power`: `require_power` concept, adds power consumption to all parts
- [ ] `vaultnet_power_technic`: adapter for Technic
- [ ] `vaultnet_power_techage`: adapter for Techage
- [ ] Each sub mod has its own `mod.conf`, `settingtypes.txt`, and textures/models folders

## Drives
- [x] Storage of items with full metadata preserved
- [x] "State" light showing fullness, going from green to red (multiple tiers or textures/overlay)
- [x] Capacity tiers (optional)
- [x] Drive item keeps its contents when carried (item metadata)

## Drive Bay
- [x] Holds a fixed number of drives
- [x] 3D visual of each inserted drive, including its state light (entities or nodebox/mesh)
- [x] Visuals update when drives are added, removed, or change fullness

## Core / Central Node
- [x] Pulls all network actions together
- [x] Formspec for adding and removing players' access
- [x] Access levels:
  - [x] Put items
  - [x] Pull items
  - [x] Change other players' access levels
- [x] Inactive texture and animated "active" texture
- [x] Only one core per network

## Inserter and Exporter
- [ ] 3D models
- [ ] Placing against a node points the device in that direction
- [ ] Advanced formspec showing the node being pointed at
- [ ] "Preview" of the target node's formspec, to visually select which inventory(ies) the Inserter puts into and the Exporter pulls from
- [ ] Inactive texture and animated active texture
- [ ] Filters and other settings (optional)

## Terminal (in `vaultnet_io`)
- [x] Browse network contents with search and paging
- [x] Take items out (1 / 10 / stack), metadata intact, respects `pull` access
- [x] Insert items, respects `put` access
- [x] Inactive texture and animated active texture

## Autocrafter
- [ ] Supports normal (shaped) recipes
- [ ] Supports shapeless recipes
- [ ] Only recipes that fit the 3x3 crafting grid (no larger grids)
- [ ] Pulls ingredients from and pushes results to the network
- [ ] Inactive and active textures

## Cables
- [x] 3D cables that connect everything
- [x] Animated "active" cable set
- [x] Adjacent connection sharing: devices connect directly to adjacent nodes (up, down, left, right, front, back; not diagonal)
- [x] Network graph discovery and caching, rebuilt on place/remove

## Toggleable Cable
- [x] 3D toggleable cable that turns off a series of connected things
- [x] Only registered when the `require_power` setting is enabled
- [x] `require_power` defaults to `false`

## Wireless Relay
- [ ] Long-distance connections
- [ ] Requires at least 2 relays to form a link
- [ ] The other end does not have a core/central node
- [ ] Forceloads both endpoints
- [ ] Server owner can enable or disable the feature (config setting)
- [ ] Optional range limit setting

## Power (`require_power`)
- [ ] Setting `require_power` (bool, default `false`)
- [ ] When enabled, every part consumes power
- [ ] Standalone power fallback inside the modpack, so no extra mods are needed
- [ ] Technic adapter
- [ ] Techage adapter
- [ ] Parts show unpowered/inactive state

## Config Settings
- [ ] `require_power` (default false)
- [ ] Wireless relay enable/disable
- [ ] Autocrafter enable/disable
- [ ] Other tunables (tick rates, drive capacities, relay range)

## Docs and Polish
- [ ] README for the modpack and for each sub mod
- [ ] Crafting recipes for all parts that use only base-game items
- [ ] Textures and models (cables, drives, bay, core, I/O, relay)
- [ ] Testing: metadata round-trip, multi-player access, power on/off, relay forceload
