# vaultnet_wireless

Optional. Wireless relays link networks over any distance, by name.

- Right-click a relay to name it. **Relays with the same name link**: their networks become
  one, and the far end does not need a core (it can be just a relay plus devices).
- `base` is a **public** name: anyone who names a relay `base` joins the link.
- `apollo:base` is a **private** name: only the player `apollo` (or someone with the
  `vaultnet_admin` privilege) can give a relay that name, so nobody else can join by typing it.
  Names are letters, digits and `_ . - :` (48 characters at most, at most one colon).
- Two or more relays of a name are **forceloaded** (transient forceloads, re-applied on every
  start from a name index kept in mod storage) so the link keeps working while nobody is
  near. This uses the server's `max_forceloaded_blocks`; the formspec says when it ran out.
- The name lives in the relay's node meta. The index (name -> positions) is only a cache to
  find partners and their blocks; it self-heals from the nodes (LBM + upkeep ABM) and stale
  entries are dropped when a position no longer holds a relay.
- Cable stubs only appear on sides that have a cable (or other device).
- Settings: `vaultnet_wireless_enabled`, `vaultnet_wireless_range` (0 = unlimited),
  `vaultnet_wireless_forceload`.

Textures: `tools/gen_wireless_textures.py vaultnet_wireless` (needs Pillow).
