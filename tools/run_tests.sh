#!/bin/bash
# Headless integration tests: starts a throwaway Luanti server with the whole modpack plus
# tools/test/vntest, which builds a small network and checks storage, access, I/O,
# autocrafting, the conflict look, entity clean-up and wireless links. Needs
# Minetest Game in ~/.minetest/games (or set GAMES_DIR).
#
#   tools/run_tests.sh            uses LUANTI or ~/games/luanti-5.17.0/bin/luanti
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LUANTI="${LUANTI:-$HOME/games/luanti-5.17.0/bin/luanti}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/world/worldmods"
for mod in "$HERE"/vaultnet_*/; do ln -s "${mod%/}" "$WORK/world/worldmods/$(basename "$mod")"; done
cp -r "$HERE/tools/test/vntest" "$WORK/world/worldmods/vntest"
{
  echo "gameid = minetest_game"
  echo "backend = sqlite3"
  echo "player_backend = sqlite3"
  echo "auth_backend = sqlite3"
  echo "mod_storage_backend = sqlite3"
  echo "world_name = vaultnet_tests"
  for m in "$HERE"/vaultnet_*/; do echo "load_mod_$(basename "$m") = true"; done
  echo "load_mod_vntest = true"
} > "$WORK/world/world.mt"
echo "mg_name = singlenode" > "$WORK/minetest.conf"

timeout 180 "$LUANTI" --server --world "$WORK/world" --gameid minetest_game --port 30777 \
    --config "$WORK/minetest.conf" --logfile "$WORK/server.log" > "$WORK/out.txt" 2>&1 || true
grep -E "^TEST|^SUMMARY|ERROR|HARNESS" "$WORK/out.txt" || { cat "$WORK/out.txt"; exit 2; }
! grep -q "^TEST.*FAIL\|ERROR\|HARNESS" "$WORK/out.txt"
