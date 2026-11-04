# vaultnet_core

The central node of a network.

- `vaultnet_core:core` (inactive), `core_active` (blue) and `core_conflict` (red). The housing
  is a metal cage (corner blocks and edge bars, open faces) around a floating, slowly
  spinning d12 crystal. Like the cables it is a connected nodebox: a plug with a collar
  appears on each side that has a cable or other device, so you can see what is attached.
- The crystal is an entity (mesh `models/vaultnet_core_crystal.obj`, recreated by an LBM, the
  status ABM and when the node is swapped): dim and slow when idle, pulsing blue when the
  network is active, flashing red and spinning fast on a conflict. The cage's accent line
  matches. The API swaps the variants by network status (`on_swapped` refreshes the crystal).
- Only one core per network: with two or more, **both** show the red conflict look and
  the network does not work until one is removed. The placer is warned in chat.
- Right-click opens a formspec: status, device count, storage used/capacity. Owners,
  players with `admin` access and `vaultnet_admin` privilege also get the access
  list: add players (put + pull), toggle put / pull / admin, remove. Everyone else
  sees their own access.
- Only owner / admins can dig the core.

Assets are generated: `tools/gen_core_assets.py vaultnet_core` (needs Pillow). The crystal mesh is single-material: each facet samples its own texel of a 16x16 frame, with the facet shading baked in.
Includes a temporary power handler that treats everything as powered when
`vaultnet_require_power` is on, until `vaultnet_power` exists.
