#!/usr/bin/env bash
set -euo pipefail

# Safety scenario contract: premerge, merge-decision, and closeout remain
# receipt-consuming fail-closed boundaries. Public launchers reject missing
# envelopes/receipts rather than delegating to legacy success branches.

search_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
while [[ "$search_dir" != "/" ]]; do
  if [[ -x "$search_dir/scripts/lib/run-script.sh" ]]; then
    exec "$search_dir/scripts/lib/run-script.sh" "${BASH_SOURCE[0]}" "$@"
  fi
  search_dir="$(dirname "$search_dir")"
done

echo "Could not locate scripts/lib/run-script.sh" >&2
exit 127
