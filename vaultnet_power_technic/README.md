# vaultnet_power_technic

Technic **Power Adapters** for `vaultnet_power` (LV, MV and HV): `vaultnet_power_technic:adapter_lv`,
`_mv`, `_hv`. Only the adapters connect to Technic cables; no other VaultNet part is a Technic machine.

An adapter sits in the VaultNet network (cables connect to it like to any device) and has a Technic
cable of its tier against it (any side). Each second it asks the network how much power it needs that
the other sources (generators, solar panels, other adapters) do not cover, capped at its capacity, and
draws that many units * `vaultnet_power_technic_eu_per_unit` EU (default 10) from the Technic grid.
The switching station supplies all of it or none; what arrives is handed to the network as supply.

| Adapter | Capacity (units/s) | Cable |
|---|---|---|
| LV | 40 | LV |
| MV | 200 | MV |
| HV | 1000 | HV |

(A typical small network draws 20-40 units/s, see `vaultnet_power`.) Capacities and the EU rate are
settings. Several adapters share the shortfall.
