# vaultnet_power

Only does anything with the setting `vaultnet_require_power` on (default off). Then every part
that consumes power -- the core, drive bays, terminal, Inserter, Exporter, autocrafter and
wireless relay -- needs it. A part without power looks inactive and does not work (an unpowered
bay's drives are out of reach, an unpowered core takes the whole network down, an unpowered relay
does not link). Cables and power sources use none. Draw is in units per second:
core 10, bay 5, terminal 2, Inserter 3, Exporter 3, autocrafter 8, relay 10, scaled by
`vaultnet_power_use_multiplier`. A device can override it with `power_use` in its `vaultnet` def.
The toggle cable (registered only with require_power) can switch a part of the network off.

## Power budget and sources

The whole network shares one budget: sources add supply (units per second), parts add demand, and
the network is powered while supply >= demand (demand only counts while the network has exactly one
core). The core formspec shows supplied / needed.

- **Generator** (`vaultnet_power:generator`): burns any furnace fuel (2 slots) for 60 units/s, and only
  lights the next item while the network needs more than it gets.
- **Solar Panel** (`vaultnet_power:solar`): 8 units/s in daylight.
- **Batteries** (`vaultnet_power:battery_small_0`, `_medium_0`, `_large_0`): 600 / 3000 / 15000 unit-seconds at up to
  20 / 60 / 200 units/s. They cover a shortfall from their charge and soak up a surplus; adapters are asked for extra
  to keep them topped up. The tooltip shows `Charge: 750 / 3,000 (25%)` and the rate (also on a new battery), the front shows the charge, a battery keeps its charge when dug and placed again (a charged one carries `no_emc`, so EMC mods do not convert it), and the
  core formspec shows stored / capacity. A part's draw can also vary (`power_draw(pos)` in its def).
- **Power Adapters** connect the network to an external power grid. **Only the adapters touch other
  mods' cables; no other VaultNet part does.** An adapter is a normal network device; each second it is
  told how much the network needs from it (what the other sources do not cover, at most its capacity,
  shared between adapters) and pulls that from its grid:
  - `vaultnet_power_technic`: LV, MV and HV adapters (Technic EU),
  - `vaultnet_power_techage`: one adapter (Techage units).

A source is a device def with `power_supply = function(pos) -> units/s`; an adapter also sets
`power_adapter = {capacity = N}` and calls `vaultnet.power.request(pos)`.
Without this mod, `require_power` leaves every part unpowered.

Textures: `tools/gen_power_textures.py vaultnet_power`, `tools/gen_adapter_textures.py .` (need Pillow).
