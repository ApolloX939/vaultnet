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
- [x] `vaultnet_components`: craft items every device is built from (own recipes; optional Technic/Techage alternatives)
- [x] `vaultnet_machines`: network-fed Smelter, Grinder, Compressor and Alloy Furnace (optional)
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

## Logistics devices (in `vaultnet_io`)
- [x] Requester: keeps a target inventory stocked with set amounts, taking only what is missing
- [x] Supplier: makes a target's items available to the network without moving them (Logistica's passive supplier)

## Machines (`vaultnet_machines`, optional)
- [x] Network-fed processing machines in the style of Technic's: Smelter, Grinder, Compressor, Alloy Furnace
- [x] One job per machine (ghost input slots), inputs from and results to the network, idle/working power draw
- [x] Recipe registry, Minetest Game basics, Technic grinding/compressing/alloy recipes imported when present

## Recipes and components
- [x] Components: wire, coil, casing, circuit, processor, actuator, storage cells I-IV, transceiver, resonator, capacitor, coupler
- [x] Every device (cables, core, drives, bay, terminal, I/O, autocrafter, relay, generator, solar, batteries, adapters, machines)
      needs components; drives climb through cell grades I-IV and circuit/processor tiers
- [x] Optional alternatives: Technic (lv_cable, copper_coil, machine_casing, control_logic_unit, battery, lv_transformer) and
      Techage (aluminum, ta4_ramchip, ta4_wlanchip, ta5_controlunit) components can stand in for the first steps
- [x] Test: every visible item craftable from real items, buildable from base items (no cycles)
- [x] EMC: every VaultNet item gets a value from the EMC mod (https://codeberg.org/F3mboyPhoenix/emc), components pinned to their own recipes (`tools/run_tests.sh --emc`)
- [ ] EMC + Techage: not covered yet. The EMC mod (https://codeberg.org/F3mboyPhoenix/emc; run the check with
      `EMC_DIR=<clone> tools/run_tests.sh --emc --techage`) has no Techage support, so in a Techage world
      `default:steel_ingot` and `default:bronze_ingot` (Techage replaces how iron/bronze are made) get no EMC value and
      neither do most VaultNet items (45 visible items, 40 unpriced as of now). Options: add `base_items/techage.lua` to the EMC
      mod (steel/bronze chain, aluminum, ...) or give the base items fallback values from `vaultnet_components/emc.lua`
      when they are unpriced (that fallback existed briefly and was removed to cover Technic only for now)
- [x] Drives with contents and charged batteries carry the `no_emc` flag (the EMC mod's tablet honors it); the EMC Link does not check it - could be raised upstream
- [ ] Balance pass in game (are the costs reasonable?) and per-game recipe files for Mineclonia / VoxeLibre / Hades / Skyblock Zero

## Machine recipe parity with Technic (standalone `vaultnet_machines`)
Goal: the Grinder, Compressor and Alloy Furnace offer the same recipes as Technic's grinder, compressor and
alloy furnace. With `technic` installed we use Technic's recipes and items (already imported at startup);
without it we register our own. Source of the list: `technic/machines/register/{grinder,compressor,alloy}_recipes.lua`
and `grindings.lua`.

### Decisions / structure
- [ ] Rule: with Technic present, Technic's recipes win (they replace our built-in ones with the same inputs, and
      our own-only items are not registered); without it, register our own items and recipes. Setting
      `vaultnet_machines_recipes` = `auto` (default) / `technic` / `own`.
- [ ] Own items live under `vaultnet_machines:` (e.g. `vaultnet_machines:copper_dust`), registered only when
      `technic` is absent. When Technic is present, `core.register_alias` our names to the matching `technic:`
      items so a world can switch between the two without losing items.
- [ ] Move the recipes into a data table (`recipes_data.lua`) with a `requires` guard per entry (mod name or item
      names), like Technic's `dependent_recipes`: an entry is only registered when its inputs and outputs exist.
- [ ] Align built-ins with Technic's values: sandstone variants grind to 2 sand (ours gives 4), alloy time 12 s for
      bronze (ours 6 s); remove or keep our extra "ore -> 2 lumps" grinding (Technic has none) - decide.
- [ ] Decide whether to defuse the vanilla crafts the way Technic does (sand -> sandstone 2x2, sandstone -> 4 sand
      infinite-sand loop). Default: leave them, setting to clear them.
- [ ] Item textures for the new items (procedural, one per dust/plate, tinted by material) + tool script.

### Recipe matching gaps in the machines
- [ ] Group inputs: Technic grinds `group:tree` and `group:wood`. Recipe lookup is by item name only; add group
      matching (a ghost item of that group matches the recipe) and show the group in the formspec.
- [ ] Recipes whose output is a list (the centrifuge/extractor outputs) are skipped by the import; only needed if we
      add those machines (below).
- [ ] Only import/register recipes whose items all exist (skips chromium, zinc, lead, sulfur, uranium and the
      modded materials unless their mods are loaded).

### Grinding (`grinder_recipes.lua`, `grindings.lua`)
- [x] Base game only, already present: cobble -> gravel, gravel -> sand, sandstone -> sand
- [ ] Base game only, missing: desert_sandstone -> 2 desert_sand, silver_sandstone -> 2 silver_sand,
      desert_stone -> desert_sand, ice -> snowblock
- [ ] Needs new items (dusts): coal, copper, gold, tin lump -> 2 dust; iron lump -> 2 iron dust (Technic: wrought
      iron); stone / sand / desert_sand / silver_sand -> stone dust
- [ ] Every dust also needs: `cooking` recipe dust -> ingot (so the Smelter works) and a grinder recipe ingot -> dust
      (bronze, copper, gold, tin, plus brass/steels if those items exist)
- [ ] Wood: group:tree -> 4 tree grindings, group:wood -> 1 grindings, grindings -> 4 sawdust; items `grindings`
      (fuel 8 s) and `sawdust` (fuel 6 s)
- [ ] Technic-only materials (chromium, zinc, lead, sulfur, uranium lumps -> dust): only with Technic; our own
      version would need our own ore/worldgen, so out of scope - leave to the import
- [ ] Mod-dependent entries (guarded): everness sandstones, farming wheat seed -> flour, moreores silver/mithril,
      nether lump, gloopores lumps, homedecor brass ingot

### Compressing (`compressor_recipes.lua`)
- [x] Already present: sand / desert_sand / silver_sand (2) -> sandstone variants
- [ ] Missing, base game: snowblock -> ice, desert_sand -> desert_stone
- [ ] Needs new items: copper ingot 5 -> copper plate, coal dust 4 -> graphite, sawdust 4 -> wood
- [ ] Technic-progression items (composite plate, carbon plate, uranium fuel): only with Technic, via the import
- [ ] Mod-dependent entries (guarded): everness coral/crystal sandstones, nether brick / rack chain

### Alloying (`alloy_recipes.lua`)
- [x] Already present: copper ingot 7 + tin ingot -> bronze ingot 8
- [ ] Needs new items: copper dust 7 + tin dust -> bronze dust 8 (12 s)
- [ ] Steel chain, needs new ingots and dusts: wrought iron 2 + coal dust -> carbon steel 2; carbon steel 2 + coal dust
      -> cast iron 2; (stainless steel needs chromium: Technic only)
- [ ] Decide: register our own wrought iron / carbon steel / cast iron items, or leave the steel chain to Technic
- [ ] Brass (copper 2 + zinc -> brass 3) needs zinc: Technic only, unless basic_materials brass + a zinc source exist
- [ ] Silicon wafer (sand 2 + coal dust 2), doped wafer (+ gold dust), rubber (raw latex 4 + coal dust 2): Technic
      progression, via the import only
- [ ] ice + empty bucket -> water bucket (needs the `bucket` mod; guarded)

### Optional extras Technic's grindings feed (not planned unless wanted)
- [ ] Extractor machine (tree grindings -> dye) and Centrifuge/separator (grindings -> sawdust + dye)
- [ ] Freezer and the other Technic recipe types

### Tests and docs
- [ ] Headless tests for each recipe family in all three configurations: Technic absent (own items registered and
      craftable through the machines), Technic present (its recipes imported, our items aliased, none duplicated)
- [ ] A test that every registered recipe's inputs and outputs are real items
- [ ] README recipe table (own vs Technic) and the new setting

## Batteries (`vaultnet_power`)
- [x] Small / Medium / Large batteries buffering the network power budget, charge kept when dug

## Config Settings
- [x] `require_power` (default false)
- [x] Wireless relay enable/disable
- [x] Autocrafter enable/disable
- [x] Other tunables (tick rates, drive capacities, relay range, power output and use)

## Docs and Polish
- [ ] README for the modpack and for each sub mod
- [x] Crafting recipes for all parts: built from VaultNet components (`vaultnet_components`), which themselves use only base-game items; optional alternatives accept Technic/Techage components
- [ ] Textures and models (cables, drives, bay, core, I/O, relay)
- [x] Testing: metadata round-trip, power on/off, relay forceload (`tools/run_tests.sh`, headless; multi-player access is only covered at API level)
