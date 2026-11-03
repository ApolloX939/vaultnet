# vaultnet_api

Shared foundation for every VaultNet mod. No gameplay content of its own.

## Device definition

Any node becomes a network device by adding a `vaultnet` table to its definition.
The API tags it with the `vaultnet_device` group and invalidates network caches
on construct/destruct automatically.

```lua
core.register_node("mymod:thing", {
    ...
    vaultnet = {
        role = "cable",              -- "cable" | "core" | "bay" | "io" | ... (free-form)
        conducts = function(pos, node) return true end,        -- optional
        can_connect = function(pos, node, dir) return true end,-- optional
        active_variant = "mymod:thing_active",   -- optional, for Network:apply_active(true)
        inactive_variant = "mymod:thing",        -- optional, for Network:apply_active(false)
        variants = {multiple_cores = "mymod:thing_red"}, -- optional, per net:status() value
        get_drive_slots = function(pos) return vaultnet.inv_slots(pos, "drives") end, -- bays
        on_drives_changed = function(pos) end,   -- bays: refresh visuals
    },
})
```

Devices connect to every directly adjacent device (6 directions). `conducts`
returning `false` isolates the node (toggle cable off). Call
`vaultnet.notify_changed(pos)` after `swap_node` changes `conducts`.

## Networks

- `vaultnet.get_network(pos)` -> network or nil (cached; rebuilt on change)
- `net:status()` -> `"ok" | "no_core" | "multiple_cores" | "unpowered"`; `net:is_active()`
- `net:get_positions_by_role(role)`, `net:get_core()`, `net:has(pos)`
- `net:apply_status(status)` swaps every device to `variants[status]`, else the active
  (status `"ok"`) or inactive variant; `net:apply_active(bool)` is shorthand for ok/inactive
- `net.incomplete` is true when the scan touched unloaded map area (not cached)
- `vaultnet.register_link_provider(fn)`: `fn(pos, node, def) -> {positions}` adds
  non-adjacent edges (used by the wireless relay)

## Storage

Drive items define `vaultnet_drive = {capacity = N}`; contents are
stored in the item's own meta keyed by the full ItemStack string, so wear and all
meta come back unchanged. Drives cannot be stored in drives.

- `net:insert(stack, opts)` -> leftover, err
- `net:extract_key(key, count, opts)` / `net:extract_name(name, count, opts)` -> stack, err
- `net:list()`, `net:count_key(key)`, `net:capacity()`
- `opts.actor = playername` enforces the core's access list; omit for automation
- `vaultnet.drive.*`: `is_drive`, `info`, `state` (1 green .. 5 red), `STATE_COLORS`, `add`, `take`, `contents`, `count`
- `vaultnet.item_key(stack)`, `vaultnet.key_to_stack(key, count)`

## Access

`vaultnet.access`: `init(pos, owner)`, `can(pos, name, "put"|"pull"|"admin")`,
`set(pos, setter, target, {put=, pull=, admin=})`, `remove`, `list`. The owner and
holders of the `vaultnet_admin` privilege always have full access.

## Power

`vaultnet.require_power` mirrors the `vaultnet_require_power` setting (default off).
`vaultnet.is_powered(pos)` is always true when off; otherwise it asks handlers
registered with `vaultnet.register_power_handler(fn(pos, node, def) -> bool|nil)`.
