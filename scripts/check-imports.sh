#!/usr/bin/env bash
#
# Deterministic check: every `resource` block in the OpenTofu config must have
# a matching `import` block. This enforces that we adopt (import) existing
# GitHub objects into state rather than creating them out-of-band, which would
# cause drift or destructive applies.
#
# Usage: scripts/check-imports.sh [file.tf ...]   (defaults to all *.tf)
#
# Resources that are intentionally create-only (brand-new objects that do not
# yet exist on GitHub) are exempted by annotating the resource block line with
# a trailing comment:  # no-import
#
set -euo pipefail

cd "$(dirname "$0")/.."

files=("$@")
if [ ${#files[@]} -eq 0 ]; then
  mapfile -t files < <(find . -name '*.tf' -not -path './.terraform/*' -print)
fi

# Collect distinct resource base addresses from `resource "type" "name"` blocks.
# Skip blocks annotated with `# no-import` on the same line.
resources=()
while IFS= read -r line; do
  if [[ "$line" == resource\ \"*\"\ \"*\"* ]]; then
    if echo "$line" | grep -q '# no-import'; then
      continue
    fi
    addr=$(echo "$line" | sed -nE 's/^[[:space:]]*resource "([^"]+)" "([^"]+)".*/\1.\2/p')
    resources+=("$addr")
  fi
done < <(cat "${files[@]}")

# Collect all import target base addresses (text before any '[').
imports=()
while IFS= read -r line; do
  if echo "$line" | grep -qE '^[[:space:]]*to[[:space:]]*='; then
    target=$(echo "$line" | sed -nE 's/^[[:space:]]*to[[:space:]]*=[[:space:]]*([^ ]+)/\1/p' | sed 's/\[.*$//')
    imports+=("$target")
  fi
done < <(cat "${files[@]}")

# Normalize import addresses: strip any leading interpolation braces.
for i in "${!imports[@]}"; do
  imports[$i]=$(echo "${imports[$i]}" | sed 's/^\${//; s/}$//')
done

rc=0
for r in "${resources[@]}"; do
  found=0
  for imp in "${imports[@]}"; do
    if [[ "$imp" == "$r" || "$imp" == "$r["* ]]; then
      found=1
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "ERROR: resource '${r}' has no matching import block." >&2
    echo "       Add an 'import' block targeting '${r}' (or annotate with '# no-import' if intentionally create-only)." >&2
    rc=1
  fi
done

if [[ $rc -eq 0 ]]; then
  echo "OK: all ${#resources[@]} resource block(s) have a matching import."
fi
exit $rc
