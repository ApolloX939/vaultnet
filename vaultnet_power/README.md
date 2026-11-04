# vaultnet_power

Only does anything with the setting `vaultnet_require_power` on (default off). Then every part
that consumes power -- the core, drive bays, terminal, Inserter, Exporter, autocrafter and
wireless relay -- needs it. A part without power looks inactive and does not work (an unpowered
bay's drives are out of reach, an unpowered core takes the whole network down, an unpowered relay
does not link). Cables and power sources use none. Draw is in units per second:
core 10, bay 5, terminal 2, Inserter 3, Exporter 3, autocrafter 8, relay 10, scaled by
`vaultnet_power_use_multiplier`. A device can override it with `power_use` in its `vaultnet` def.
The toggle cable (registered only with require_power) can switch a part of the network off.

## Backends (`vaultnet_power_backend`)

- **standalone** (built in): the whole network shares one budget. `Generator` burns fuel (any
  furnace fuel, 2 slots) for 60 units/s, and only lights the next item while the network needs more
  than it gets. `Solar Panel` gives 8 units/s in daylight. If supply >= demand the network is
  powered, otherwise nothing is. The core formspec shows supplied / needed.
- **technic**: `vaultnet_power_technic` makes every part a Technic LV consumer.
- **techage**: `vaultnet_power_techage` lets every part draw from a Techage power network.
- **auto** (default): Technic if installed, else Techage, else standalone.

Backends register with `vaultnet.power.register_backend(name, {available, init, handler})`.
Without this mod, `require_power` leaves every part unpowered.

Textures: `tools/gen_power_textures.py vaultnet_power` (needs Pillow).
