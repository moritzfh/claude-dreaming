#!/usr/bin/env bash
# Static checks for level folders (runs in CI, works locally too):
#   bash tools/ci/check_rules.sh [base-ref]
# With a base ref (e.g. origin/main) it also looks at what a pull request changes.
set -u
fail=0
err()  { echo "::error::$*"; fail=1; }
warn() { echo "::warning::$*"; }

MAX_LEVEL_MB=30
MAX_FILE_MB=20

for dir in levels/*/; do
  id=$(basename "$dir")
  [[ "$id" == _* ]] && continue
  [[ "$id" =~ ^[a-z0-9_]+$ ]] || err "levels/$id: folder name must be lowercase letters, digits and _ only"
  [[ -f "$dir/level.tres" ]] || err "levels/$id: missing level.tres"
  [[ -f "$dir/painting.png" ]] || err "levels/$id: missing painting.png (1280x720 screenshot)"
  size_kb=$(du -sk --exclude=_build --exclude='*.import' "$dir" | cut -f1)
  (( size_kb > MAX_LEVEL_MB * 1024 )) && err "levels/$id: folder is $((size_kb / 1024)) MB (limit ${MAX_LEVEL_MB} MB)"
  while IFS= read -r f; do
    err "$f is bigger than ${MAX_FILE_MB} MB"
  done < <(find "$dir" -type f -size +${MAX_FILE_MB}M -not -path '*/_build/*')
  while IFS= read -r f; do
    err "$f: no class_name in level scripts (use preload instead) – names are global and would clash"
  done < <(grep -rlE '^\s*class_name\s' "$dir" --include='*.gd' 2>/dev/null)
  while IFS= read -r line; do
    err "levels/$id references another level's files: $line"
  done < <(grep -rhoE 'res://levels/[a-z0-9_]+/' "$dir" --include='*.gd' --include='*.tscn' --include='*.tres' --include='*.gdshader' 2>/dev/null | sort -u | grep -v "res://levels/$id/" | grep -v "res://levels/_template/")
done

MAX_ROOM_MB=5
for dir in rooms/*/; do
  [[ -d "$dir" ]] || continue
  id=$(basename "$dir")
  [[ "$id" == _* ]] && continue
  [[ "$id" =~ ^[a-z0-9_]+$ ]] || err "rooms/$id: folder name must be lowercase letters, digits and _ only"
  [[ -f "$dir/room.tres" ]] || err "rooms/$id: missing room.tres"
  if [[ -f "$dir/room.png" ]]; then
    dims=$(file "$dir/room.png" | grep -oE '[0-9]+ x [0-9]+' | head -1)
    w=${dims%% x *}; h=${dims##* x }
    [[ "$h" == "216" ]] || err "rooms/$id/room.png must be 216 px high (is ${h:-?})"
    [[ -n "$w" ]] && (( w < 160 || w > 640 )) && err "rooms/$id/room.png should be 160-640 px wide (is $w)"
  else
    err "rooms/$id: missing room.png"
  fi
  size_kb=$(du -sk --exclude=_build --exclude='*.import' "$dir" | cut -f1)
  (( size_kb > MAX_ROOM_MB * 1024 )) && err "rooms/$id: folder is $((size_kb / 1024)) MB (limit ${MAX_ROOM_MB} MB)"
  while IFS= read -r f; do
    err "$f: no class_name in room scripts (use preload instead)"
  done < <(grep -rlE '^\s*class_name\s' "$dir" --include='*.gd' 2>/dev/null)
done

# the same uid in two files breaks Godot's resource lookup (happens when a
# folder is copied together with its *.uid / *.import files)
dups=$(find . -name '*.uid' -not -path './.godot/*' -exec cat {} + 2>/dev/null | sort | uniq -d)
[[ -n "$dups" ]] && err "duplicate uids (did you copy *.uid files from another folder? delete the copies): $dups"

if [[ $# -ge 1 ]]; then
  base=$1
  changed=$(git diff --name-only "$base"...HEAD 2>/dev/null)
  lvl_dirs=$(echo "$changed" | grep -oE '^levels/[^/]+' | sort -u)
  room_dirs=$(echo "$changed" | grep -oE '^rooms/[^/]+' | sort -u)
  core=$(echo "$changed" | grep -vE '^(levels|rooms)/' | grep -v '^$')
  if [[ ( -n "$lvl_dirs" || -n "$room_dirs" ) && -n "$core" ]]; then
    warn "This PR changes a level/room AND files outside levels/ and rooms/ – please split core changes into their own PR: $(echo $core | tr '\n' ' ')"
  fi
  r=$(echo "$room_dirs" | grep -c . || true)
  (( r > 1 )) && warn "This PR touches $r rooms – one room per person"

  n=$(echo "$lvl_dirs" | grep -c . || true)
  (( n > 1 )) && warn "This PR touches $n level folders – one level per PR is easier to review"
fi

if (( fail )); then echo "Rule check failed."; exit 1; fi
echo "Rule check OK."
