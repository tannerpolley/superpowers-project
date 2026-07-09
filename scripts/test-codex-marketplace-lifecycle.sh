#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v codex >/dev/null || { echo "codex CLI is required for marketplace lifecycle proof" >&2; exit 127; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
home="$tmp/codex-home"; market="$tmp/market"; source="$market/plugins/superpowers-project"
mkdir -p "$home" "$market/.agents/plugins" "$source"
cp -a "$root/.codex-plugin" "$root/assets" "$root/skills" "$root/scripts" "$source/"
python3 - "$market/.agents/plugins/marketplace.json" <<'PY'
import json, sys
json.dump({"name":"fixture","interface":{"displayName":"Fixture"},"plugins":[{"name":"superpowers-project","source":{"source":"local","path":"./plugins/superpowers-project"},"policy":{"installation":"AVAILABLE","authentication":"ON_INSTALL"},"category":"Engineering"}]}, open(sys.argv[1],"w"))
PY
export CODEX_HOME="$home"
codex plugin marketplace add "$market" --json >/dev/null
available="$(codex plugin list --available --json)"
python3 - "$available" <<'PY'
import json, sys
d=json.loads(sys.argv[1]); assert any(p.get("pluginId") == "superpowers-project@fixture" for p in d["available"])
PY
codex plugin add superpowers-project@fixture --json >/dev/null
installed="$(codex plugin list --json)"
python3 - "$installed" <<'PY'
import json, sys
d=json.loads(sys.argv[1]); assert any(p.get("pluginId") == "superpowers-project@fixture" and p.get("installed") for p in d["installed"])
PY
codex plugin remove superpowers-project@fixture --json >/dev/null
printf '%s\n' '{"ok":true,"phase":"marketplace-lifecycle","reason":"real Codex marketplace add/list/install/remove passed in isolated CODEX_HOME"}'
