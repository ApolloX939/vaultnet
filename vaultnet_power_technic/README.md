# vaultnet_power_technic

Technic adapter for `vaultnet_power` (used when `vaultnet_require_power` is on and the backend
setting is `auto` or `technic`).

Every part that consumes power -- core, drive bays, terminal, Inserter, Exporter, autocrafter,
wireless relay -- is registered as a Technic **LV receiver**. Put an LV cable against a part (any
side) and it draws its demand (core 10, bay 5, terminal 2, Inserter/Exporter 3, autocrafter 8,
relay 10 EU/s, scaled by `vaultnet_power_use_multiplier`) from the network's switching station.
A part is powered when its `LV_EU_input` covers its `LV_EU_demand`; otherwise it looks inactive
and does nothing. Cables and the built-in generators/solar panels are not involved.

Technic's "No Network" infotext replaces a part's own infotext while it is not on a Technic network.
