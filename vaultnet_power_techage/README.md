# vaultnet_power_techage

The Techage **Power Adapter** for `vaultnet_power`: `vaultnet_power_techage:adapter`. Only the adapter
connects to Techage cables; no other VaultNet part is a Techage consumer.

The adapter sits in the VaultNet network (cables connect to it like to any device) and has a Techage
electric cable (or any node of that network) against it. Techage works in 2 second cycles: each cycle
the adapter asks the network how many units per second it needs from it (what the other sources do not
cover, at most 60) and tries to take ceil(units * `vaultnet_power_techage_scale`) Techage units (default
scale 0.5, so 40 units/s costs 20 Techage units per cycle). If it gets them all it delivers those units
for the next 4 seconds, otherwise nothing.
