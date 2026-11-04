#!/bin/bash
# Headless integration tests: starts a throwaway Luanti server with the whole modpack plus
# tools/test/vntest, which builds a small network and checks storage, access, I/O,
# autocrafting, the conflict look, entity clean-up and wireless links. Needs
# Minetest Game in ~/.minetest/games (or set GAMES_DIR).
#
#   tools/run_tests.sh            uses LUANTI or ~/games/luanti-5.17.0/bin/luanti
#   tools/run_tests.sh --power    the same with vaultnet_require_power on (standalone backend)
#   tools/run_tests.sh --technic  require_power with the Technic adapter (needs technic, pipeworks,
#                                 basic_materials, xcompat, fakelib in MODS_DIR, default ~/.minetest/mods)
#   tools/run_tests.sh --techage  require_power with the Techage adapter (needs techage_modpack there)
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LUANTI="${LUANTI:-$HOME/games/luanti-5.17.0/bin/luanti}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

MODS_DIR="${MODS_DIR:-$HOME/.minetest/mods}"
POWER=0
EXTRA=()
case "$1" in
  --power) POWER=1 ;;
  --technic) POWER=1; EXTRA=(vaultnet_power_technic) ;;
  --techage) POWER=1; EXTRA=(vaultnet_power_techage) ;;
esac

mkdir -p "$WORK/world/worldmods"
for mod in "$HERE"/vaultnet_*/; do
  name="$(basename "$mod")"
  case "$name" in
    vaultnet_power_technic|vaultnet_power_techage)
      [[ " ${EXTRA[*]} " == *" $name "* ]] || continue ;;
  esac
  ln -s "${mod%/}" "$WORK/world/worldmods/$name"
done
link() { [ -e "$1" ] && ln -sfn "$1" "$WORK/world/worldmods/$(basename "$1")" || { echo "missing mod: $1" >&2; exit 3; }; }
if [ "$1" = "--technic" ]; then
  for m in technic/technic technic/technic_worldgen pipeworks xcompat fakelib techage_modpack/basic_materials; do link "$MODS_DIR/$m"; done
elif [ "$1" = "--techage" ]; then
  for m in techage_modpack/techage techage_modpack/networks techage_modpack/tubelib2 techage_modpack/lcdlib techage_modpack/basic_materials techage_modpack/doclib techage_modpack/safer_lua techage_modpack/minecart xcompat fakelib; do link "$MODS_DIR/$m"; done
fi
cp -r "$HERE/tools/test/vntest" "$WORK/world/worldmods/vntest"
{
  echo "gameid = minetest_game"
  echo "backend = sqlite3"
  echo "player_backend = sqlite3"
  echo "auth_backend = sqlite3"
  echo "mod_storage_backend = sqlite3"
  echo "world_name = vaultnet_tests"
  for m in "$WORK"/world/worldmods/*/; do n="$(basename "$m")"; [ "$n" = vntest ] || echo "load_mod_$n = true"; done
  echo "load_mod_vntest = true"
} > "$WORK/world/world.mt"
echo "mg_name = singlenode" > "$WORK/minetest.conf"
[ "$POWER" = 1 ] && echo "vaultnet_require_power = true" >> "$WORK/minetest.conf"

timeout 180 "$LUANTI" --server --world "$WORK/world" --gameid minetest_game --port 30777 \
    --config "$WORK/minetest.conf" --logfile "$WORK/server.log" > "$WORK/out.txt" 2>&1 || true
grep -E "^TEST|^SUMMARY|ERROR|HARNESS" "$WORK/out.txt" || { cat "$WORK/out.txt"; exit 2; }
! grep -q "^TEST.*FAIL\|ERROR\|HARNESS" "$WORK/out.txt"
