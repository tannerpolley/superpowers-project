#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "${1:-}" == "-DispatchProbe" || "${1:-}" == "--dispatch-probe" ]]; then
  exec "$root/scripts/lib/run-script.sh" "${BASH_SOURCE[0]}" "$@"
fi
command -v codex >/dev/null || { echo "codex CLI is required for marketplace lifecycle proof" >&2; exit 127; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
home="$tmp/codex-home"; market="$tmp/market"
mkdir -p "$home"
"$root/scripts/sync-live.sh" \
  -LivePluginRoot "$market/.codex/plugins/superpowers-project" \
  -MarketplacePath "$market/.agents/plugins/marketplace.json" >/dev/null
export CODEX_HOME="$home"
codex plugin marketplace add "$market" --json >/dev/null
available="$(codex plugin list --available --json)"
python3 - "$available" <<'PY'
import json, sys
d=json.loads(sys.argv[1]); assert any(p.get("pluginId") == "superpowers-project@personal" for p in d["available"])
PY
codex plugin add superpowers-project@personal --json >/dev/null
installed="$(codex plugin list --json)"
python3 - "$installed" <<'PY'
import json, sys
d=json.loads(sys.argv[1]); assert any(p.get("pluginId") == "superpowers-project@personal" and p.get("installed") for p in d["installed"])
PY
codex plugin remove superpowers-project@personal --json >/dev/null
printf '%s\n' '{"ok":true,"phase":"marketplace-lifecycle","reason":"real Codex marketplace add/list/install/remove passed in isolated CODEX_HOME"}'
