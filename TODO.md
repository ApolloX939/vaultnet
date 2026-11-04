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
- [x] `vaultnet_io`: Terminal, Inserter and Exporter
- [x] `vaultnet_autocrafter`: autocrafter (opt-in)
- [x] `vaultnet_wireless`: wireless relay (opt-in, forceloads both ends)
- [x] `vaultnet_power`: `require_power` concept, adds power consumption to all parts
- [x] `vaultnet_power_technic`: Power Adapters for Technic (LV, MV, HV)
- [x] `vaultnet_power_techage`: Power Adapter for Techage
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
- [x] 3D models
- [x] Placing against a node points the device in that direction
- [x] Advanced formspec showing the node being pointed at
- [x] "Preview" of the target node's formspec, to visually select which inventory(ies) the Inserter pulls from (into the network) and the Exporter puts into (out of the network)
- [x] Inactive texture and animated active texture
- [x] Filters and other settings (optional)

## Terminal (in `vaultnet_io`)
- [x] Browse network contents with search and paging
- [x] Take items out (1 / 10 / stack), metadata intact, respects `pull` access
- [x] Insert items, respects `put` access
- [x] Inactive texture and animated active texture

## Autocrafter
- [x] Supports normal (shaped) recipes
- [x] Supports shapeless recipes
- [x] Only recipes that fit the 3x3 crafting grid (no larger grids)
- [x] Pulls ingredients from and pushes results to the network
- [x] Inactive and active textures

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
- [x] Long-distance connections, linked by relay name (`name` public, `player:name` private)
- [x] Requires at least 2 relays to form a link
- [x] The other end does not have a core/central node
- [x] Forceloads both endpoints
- [x] Server owner can enable or disable the feature (config setting)
- [x] Optional range limit setting

## Power (`require_power`)
- [x] Setting `require_power` (bool, default `false`)
- [x] When enabled, every part consumes power
- [x] Standalone power fallback inside the modpack, so no extra mods are needed
- [x] Technic Power Adapter (LV, MV, HV)
- [x] Techage Power Adapter
- [x] Parts show unpowered/inactive state

## Machines (`vaultnet_machines`, optional)
- [x] Network-fed processing machines in the style of Technic's: Smelter, Grinder, Compressor, Alloy Furnace
- [x] One job per machine (ghost input slots), inputs from and results to the network, idle/working power draw
- [x] Recipe registry, Minetest Game basics, Technic grinding/compressing/alloy recipes imported when present

## Batteries (`vaultnet_power`)
- [x] Small / Medium / Large batteries buffering the network power budget, charge kept when dug

## Config Settings
- [x] `require_power` (default false)
- [x] Wireless relay enable/disable
- [x] Autocrafter enable/disable
- [x] Other tunables (tick rates, drive capacities, relay range, power output and use)

## Docs and Polish
- [ ] README for the modpack and for each sub mod
- [ ] Crafting recipes for all parts that use only base-game items
- [ ] Textures and models (cables, drives, bay, core, I/O, relay)
- [x] Testing: metadata round-trip, power on/off, relay forceload (`tools/run_tests.sh`, headless; multi-player access is only covered at API level)
