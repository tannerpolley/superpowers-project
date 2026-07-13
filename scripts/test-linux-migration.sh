#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "${1:-}" == "-DispatchProbe" || "${1:-}" == "--dispatch-probe" ]]; then
  exec "$repo_root/scripts/lib/run-script.sh" "${BASH_SOURCE[0]}" "$@"
fi
cd "$repo_root"

failures=()

add_failure() {
  failures+=("$1")
}

if find scripts skills .github -name '*.ps1' -print -quit | grep -q .; then
  add_failure "active script/workflow tree still contains .ps1 files"
fi

if find scripts skills -name '*.sh' -type f ! -perm -111 -print -quit | grep -q .; then
  add_failure "one or more bash scripts are not executable"
fi

if rg -n --hidden -S '(pwsh|powershell|ExecutionPolicy|windows-latest|choco install|\\.ps1|scripts\\\\|C:\\\\Users\\\\|cmd\\.exe|powershell\\.exe)' \
  AGENTS.md README.md .codex-plugin .github scripts skills docker \
  -g '!*.png' \
  -g '!scripts/test-linux-migration.sh' \
  -g '!scripts/lib/superpowers_project_cli.py' >/tmp/superpowers-linux-migration-rg.txt; then
  add_failure "active runtime surfaces still contain Windows/PowerShell references"
fi

if [[ -f .github/workflows/validate.yml ]]; then
  if ! rg -n 'runs-on:\s+ubuntu-latest' .github/workflows/validate.yml >/dev/null; then
    add_failure "GitHub Actions validation workflow must run on ubuntu-latest"
  fi
  if ! rg -n 'shell:\s+bash' .github/workflows/validate.yml >/dev/null; then
    add_failure "GitHub Actions validation workflow must use bash"
  fi
fi

if ((${#failures[@]} > 0)); then
  printf '{"ok":false,"phase":"linux-migration","failures":['
  for i in "${!failures[@]}"; do
    ((i > 0)) && printf ','
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]), end="")' "${failures[$i]}"
  done
  printf ']}\n'
  if [[ -s /tmp/superpowers-linux-migration-rg.txt ]]; then
    sed -n '1,80p' /tmp/superpowers-linux-migration-rg.txt >&2
  fi
  exit 1
fi

printf '{"ok":true,"phase":"linux-migration"}\n'
