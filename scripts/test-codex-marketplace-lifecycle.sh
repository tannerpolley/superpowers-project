#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
home="$(mktemp -d)"; bin="$(mktemp -d)"; trap 'rm -rf "$home" "$bin"' EXIT
export CODEX_HOME="$home"
cat >"$bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state="$CODEX_HOME/plugins.json"; mkdir -p "$(dirname "$state")"
cmd="${1:-}"; sub="${2:-}"
case "$cmd $sub" in
  "plugin marketplace") [[ "${3:-}" == add ]] && touch "$CODEX_HOME/marketplace-added";;
  "plugin add") mkdir -p "$CODEX_HOME/plugins/superpowers-project"; cp -a "${3#local:}/." "$CODEX_HOME/plugins/superpowers-project/"; echo installed >"$state";;
  "plugin list") test -f "$state";;
  "plugin remove") rm -rf "$CODEX_HOME/plugins/superpowers-project"; rm -f "$state";;
  *) exit 64;;
esac
EOF
chmod +x "$bin/codex"; export PATH="$bin:$PATH"
codex plugin marketplace add "$root"
codex plugin add "local:$root"
codex plugin list
test -f "$CODEX_HOME/plugins/superpowers-project/.codex-plugin/plugin.json"
codex plugin remove superpowers-project
test ! -e "$CODEX_HOME/plugins/superpowers-project"
python3 -m unittest "$root/tests/test_package_provenance.py" -q
printf '%s\n' '{"ok":true,"phase":"marketplace-lifecycle","reason":"isolated marketplace add/list/remove passed"}'
