#!/usr/bin/env bash
set -euo pipefail
plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "${1:-}" == "-DispatchProbe" || "${1:-}" == "--dispatch-probe" ]]; then
  exec "$plugin_root/scripts/lib/run-script.sh" "${BASH_SOURCE[0]}" "$@"
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
project="$tmp/project"
outside="$tmp/outside"
mkdir -p "$project/docs/superpowers/runs" "$outside"
git -C "$project" init -q
cat > "$project/mode.json" <<'JSON'
{"question_id":"project_workflow_mode","source":"test","selected_mode":"manual","repo_root":"external","plugin_manifest_version":"1","plugin_contract_hash":"x","started_at":"2026-01-01T00:00:00Z","autonomy_scope":"ask-every-material-decision","mutation_scope":"project","candidate_scope":"one","route_policy":{"one_route_only":false},"proof_policy":{"required":true},"stop_conditions":["failed-validation"],"downstream_ledger_paths":["docs/superpowers/runs/result.json"]}
JSON
cat > "$project/auth.json" <<JSON
{"question_id":"project_workflow_mode","source":"request_user_input","selected_mode":"auto","repo_root":"$project","request_fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","autonomy_scope":"one-outcome-lifecycle","candidate_scope":["raw-request"],"route_policy":{"selected_mode":"agent-chooses","issue_route":"evidence-based","one_outcome_only":true,"continue_to_next_candidate":false},"merge_permission":{"selected_mode":"preauthorized-after-clean-premerge","require_clean_premerge":true},"mutation_scope":["current-repo","development-branch"],"required_proof":["plan-proof-oracle","verification-receipts","cleanup-hook","premerge-proof","closeout-proof"],"stop_conditions":["missing-proof","dirty-unsafe-state","failed-validation","decision-outside-policy"]}
JSON
before="$(find "$plugin_root" -type f -not -path '*/__pycache__/*' -printf '%P\n' | sort)"
set +e
bash "$plugin_root/scripts/validate-workflow-mode-ledger.sh" -RepoRoot "$project" -ModeLedgerPath mode.json >/dev/null
valid_status=$?
(cd "$project" && bash "$plugin_root/scripts/validate-workflow-mode-ledger.sh" -RepoRoot . -ModeLedgerPath mode.json >/dev/null)
sibling_status=$?
bash "$plugin_root/scripts/validate-workflow-mode-ledger.sh" -RepoRoot "$project" -ModeLedgerPath ../outside >/dev/null 2>&1
status=$?
set -e
[[ $valid_status -eq 0 ]]
[[ $sibling_status -eq 0 ]]
[[ $status -ne 0 ]]
bash "$plugin_root/scripts/validate-auto-mode-authorization.sh" -RepoRoot "$project" -AuthorizationPath auth.json >/dev/null
(cd "$project" && bash "$plugin_root/scripts/validate-auto-mode-authorization.sh" -RepoRoot . -AuthorizationPath auth.json >/dev/null)
set +e
reason=$(bash "$plugin_root/scripts/validate-workflow-mode-ledger.sh" -RepoRoot "$project" -ModeLedgerPath ../outside 2>&1)
reason2=$(bash "$plugin_root/scripts/validate-auto-mode-authorization.sh" -RepoRoot "$project" -AuthorizationPath ../outside 2>&1)
set -e
[[ "$reason" == *"outside project root"* ]]
[[ "$reason2" == *"outside project root"* ]]
after="$(find "$plugin_root" -type f -not -path '*/__pycache__/*' -printf '%P\n' | sort)"
[[ "$before" == "$after" ]]
echo "cross-repo runtime checks passed"
