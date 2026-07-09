#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "${1:-}" == "-DispatchProbe" || "${1:-}" == "--dispatch-probe" ]]; then
  exec "$root/scripts/lib/run-script.sh" "${BASH_SOURCE[0]}" "$@"
fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
live="$tmp/live"; market="$tmp/marketplace.json"
"$root/scripts/install.sh" -SkipValidation -LivePluginRoot "$live" -MarketplacePath "$market" >/dev/null
before="$(sha256sum "$live/.codex-plugin/plugin.json")"
cp -a "$root" "$tmp/forged"
python3 - "$tmp/forged/.codex-plugin/plugin.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["name"]="forged"; open(p,"w").write(json.dumps(d))
PY
if "$tmp/forged/scripts/install.sh" -SkipValidation -LivePluginRoot "$live" -MarketplacePath "$market" >/dev/null 2>&1; then
  echo "forged update unexpectedly installed" >&2; exit 1
fi
test "$before" = "$(sha256sum "$live/.codex-plugin/plugin.json")"
python3 -m unittest "$root/tests/test_package_provenance.py" -q
printf '%s\n' '{"ok":true,"phase":"install-transaction","reason":"invalid update preserved previous install"}'
