# vaultnet_power_techage

Techage adapter for `vaultnet_power` (used when `vaultnet_require_power` is on and the backend
setting is `auto` or `techage`; `auto` prefers Technic when both are installed).

Every part that consumes power is registered as a consumer on Techage's electric cable network.
Put a Techage electric cable (or any node of that network) against a part and it draws from the
network's generators and storage. Techage works in 2 second cycles, so a part takes
ceil(units per second / 2) units per cycle (core 5, bay 3, terminal 1, Inserter/Exporter 2,
autocrafter 4, relay 5 by default; scaled by `vaultnet_power_use_multiplier`). A part that gets
its full draw counts as powered for the next 4 seconds; otherwise it looks inactive and does nothing.
