# vaultnet_core

The central node of a network.

- `vaultnet_core:core` (inactive), `core_active` (animated blue crystal),
  `core_conflict` (flashing red crystal). 3D mesh `models/vaultnet_core_core.obj`
  (frame with a floating crystal). The API swaps the variants by network status.
- Only one core per network: with two or more, **both** show the red conflict look and
  the network does not work until one is removed. The placer is warned in chat.
- Right-click opens a formspec: status, device count, storage used/capacity. Owners,
  players with `admin` access and `vaultnet_admin` privilege also get the access
  list: add players (put + pull), toggle put / pull / admin, remove. Everyone else
  sees their own access.
- Only owner / admins can dig the core.

Assets are generated: `tools/gen_core_assets.py vaultnet_core` (needs Pillow). The mesh is single-material: each variant has one 16x32 texture (metal frame on top, crystal glow below).
Includes a temporary power handler that treats everything as powered when
`vaultnet_require_power` is on, until `vaultnet_power` exists.
