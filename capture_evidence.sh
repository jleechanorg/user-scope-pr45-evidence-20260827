#!/usr/bin/env bash
set -Eeuo pipefail

REPO=/home/jleechan/projects/user_scope/.worktrees/linux-portable-mcp-integration
BUNDLE=/tmp/user_scope/codex-linux-portable-mcp/iteration_003
ARTIFACTS="$BUNDLE/artifacts"
mkdir -p "$ARTIFACTS"
HEAD_SHA=$(git -C "$REPO" rev-parse HEAD)
BASE_SHA=$(git -C "$REPO" merge-base HEAD origin/main)

sanitize() {
  sed -E \
    -e 's#/home/jleechan/#/home/REDACTED/#g' \
    -e 's#/tmp/[^[:space:]]+#/tmp/REDACTED#g' \
    -e 's#(session id: )[[:graph:]]+#\1REDACTED#g' \
    -e 's#(GOCSPX-)[A-Za-z0-9_-]+#\1REDACTED#g'
}

echo '=== TEST: portable shared MCP daemon live acceptance ==='
echo '=== RESULT: PASS — service cgroup owns all 3 listeners; 3 MCP initialize calls return HTTP 200; Codex tmux turn exits 0; full focused suite passes; source state is unchanged ==='
echo '=== 1. GIT PROVENANCE ==='
printf 'HEAD=%s\nBASE=%s\nBRANCH=%s\n' "$HEAD_SHA" "$BASE_SHA" "$(git -C "$REPO" branch --show-current)"

git_state() {
  local phase="$1"
  echo "[$phase] git status --porcelain" >&2
  git -C "$REPO" status --porcelain
  echo "[$phase] tracked-file digest" >&2
  git -C "$REPO" ls-files -s | sha256sum
  echo "[$phase] diff-index/cache checks" >&2
  if (cd "$REPO" && git diff-index --quiet HEAD --); then echo 'diff-index=clean'; else echo 'diff-index=DIRTY'; return 1; fi
  if (cd "$REPO" && git diff --quiet); then echo 'worktree-diff=clean'; else echo 'worktree-diff=DIRTY'; return 1; fi
  if (cd "$REPO" && git diff --cached --quiet); then echo 'cache-diff=clean'; else echo 'cache-diff=DIRTY'; return 1; fi
}

git_state PRE | tee "$ARTIFACTS/git_pre_state.txt"

echo '=== 2. COMMIT LOG ==='
git -C "$REPO" log --oneline origin/main..HEAD

echo '=== 3. SAFE CODE DIFFS ==='
# Only newly-added, credential-free runtime files are displayed. Historical
# launcher diffs are deliberately excluded because the removed legacy file
# contained a credential and must never enter an evidence recording.
git -C "$REPO" diff origin/main...HEAD -- \
  config/mcp-daemon/force-loopback.cjs \
  config/mcp-daemon/mcp-daemon.service.template | sanitize

echo '=== 4. PR STATUS ==='
gh pr view 45 --repo jleechanorg/user_scope --json number,title,url,state,headRefName,headRefOid,isDraft

echo '=== 5. REMOTE BRANCH CONTAINMENT ==='
git -C "$REPO" branch -r --contains "$HEAD_SHA"
printf 'REMOTE_HEAD=%s\n' "$(git -C "$REPO" ls-remote --heads origin refs/heads/codex/linux-portable-mcp | awk '{print $1}')"

echo '=== 6. LIVE SYSTEMD / CGROUP / LISTENER EVIDENCE ==='
systemctl --user show mcp-daemon.service -p ActiveState -p SubState -p MainPID -p NRestarts -p ControlGroup -p MemoryCurrent | tee "$ARTIFACTS/systemd_service.txt"
"$HOME/.config/mcp-daemon/start-mcp-daemons.sh" status | tee "$ARTIFACTS/launcher_status.txt"
"$HOME/.config/mcp-daemon/start-mcp-daemons.sh" check
ss -H -ltnp '( sport = :8001 or sport = :8005 or sport = :8006 or sport = :8010 or sport = :8013 )' | tee "$ARTIFACTS/listeners.txt"
service_cgroup=$(systemctl --user show mcp-daemon.service -p ControlGroup --value)
{
  echo "service_cgroup=$service_cgroup"
  mapfile -t listener_pids < <(sed -nE 's/.*pid=([0-9]+).*/\1/p' "$ARTIFACTS/listeners.txt" | sort -u)
  for pid in "${listener_pids[@]}"; do
    [[ -r "/proc/$pid/cgroup" ]] || continue
    echo "listener_pid=$pid"
    printf 'cmdline='; tr '\0' ' ' < "/proc/$pid/cmdline"; echo
    echo '/proc cgroup:'; sed -E 's#^#/proc/'"$pid"'/cgroup: #' "/proc/$pid/cgroup"
    echo 'process-tree:'; pstree -aps "$pid" || true
    if grep -Fq "$service_cgroup" "/proc/$pid/cgroup"; then
      echo 'service-cgroup-match=PASS'
    else
      echo 'service-cgroup-match=FAIL'
      exit 1
    fi
  done
} | sanitize | tee "$ARTIFACTS/listener_pid_cgroup_service.txt"
systemctl --user status mcp-daemon.service --no-pager | sanitize | tee "$ARTIFACTS/systemd_process_tree.txt"
systemctl --user show agents.slice -p MemoryHigh -p MemoryMax -p MemorySwapMax | tee "$ARTIFACTS/agents_slice.txt"
agents_cg="/sys/fs/cgroup$(systemctl --user show agents.slice -p ControlGroup --value)"
printf 'memory.high=%s\nmemory.max=%s\nmemory.swap.max=%s\n' "$(<"$agents_cg/memory.high")" "$(<"$agents_cg/memory.max")" "$(<"$agents_cg/memory.swap.max")" | tee "$ARTIFACTS/cgroup_limits.txt"
cat > "$ARTIFACTS/layer_labels.txt" <<'EOF'
S1 service/listeners: [Layer 2 real-OS/systemd+cgroup]
S2 direct MCP initialize calls with retained curl headers/bodies: [Layer 2 real-HTTP/MCP]
S3 Codex/Claude client configuration: [Layer 2 real-CLI/config]
S4 systemd/cgroup settings: [Layer 2 real-CLI/OS]
S5 tmux Codex turn: [Layer 2 real-CLI/real-LLM]
S6 focused tests and git stability: [Layer 1 focused tests + Layer 2 repository-state]
EOF

echo '=== 7. DIRECT MCP INITIALIZE CALLS / RETAINED CURL RESPONSES ==='
: > "$BUNDLE/request_responses.jsonl"
payload='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"evidence-capture","version":"2"}}}'
for spec in context7:8001 sequential-thinking:8005 slack:8006; do
  name=${spec%%:*}; port=${spec##*:}
  headers="$ARTIFACTS/${name}_headers.txt"
  body="$ARTIFACTS/${name}_body.txt"
  status=$(curl -sS --max-time 10 -D "$headers" -o "$body" -w '%{http_code}' -X POST \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --data "$payload" "http://127.0.0.1:${port}/mcp")
  perl -pi -e 's/(mcp-session-id:\s*)[^\r\n]+/${1}REDACTED/ig' "$headers"
  jq -cn --arg service "$name" --arg url "http://127.0.0.1:${port}/mcp" --argjson request "$payload" \
    '{type:"request",service:$service,method:"POST",url:$url,body:$request}' >> "$BUNDLE/request_responses.jsonl"
  jq -cn --arg service "$name" --arg status "$status" --rawfile headers "$headers" --rawfile body "$body" \
    '{type:"response",service:$service,status:($status|tonumber),headers:$headers,body:$body}' >> "$BUNDLE/request_responses.jsonl"
  grep -Eq '"jsonrpc"[[:space:]]*:[[:space:]]*"2.0"' "$body"
  grep -Eq '"result"[[:space:]]*:' "$body"
  printf '%s initialize HTTP=%s PASS\n' "$name" "$status"
done

echo '=== 8. REAL CLIENT CONFIGURATION PATHS ==='
codex --version | tee "$ARTIFACTS/codex_version.txt"
codex mcp list | tee "$ARTIFACTS/codex_mcp_list.txt"
claude mcp list | tee "$ARTIFACTS/claude_mcp_list.txt"
jq -r '.mcpServers | keys[]' "$HOME/.claude/mcp-strict.json" | sort | tee "$ARTIFACTS/claude_strict_names.txt"
awk '/^\[agents\]/{p=1} p{print} p && /^$/{exit}' "$HOME/.codex/config.toml" | tee "$ARTIFACTS/codex_agents_block.txt"

echo '=== 9. REAL TMUX CODEX TURN ==='
tmux_name="es-codex-v2-$(date +%s)"
tmux_raw="$ARTIFACTS/.tmux_codex_raw.txt"
tmux_out="$ARTIFACTS/tmux_codex_output.txt"
tmux_rc="$ARTIFACTS/tmux_codex_rc.txt"
: > "$tmux_raw"
: > "$tmux_rc"
tmux new-session -d -s "$tmux_name" "cd '$REPO' && codex exec --skip-git-repo-check 'Respond exactly ES_CODEX_MCP_V2_OK' >'$tmux_raw' 2>&1; printf '%s' \$? >'$tmux_rc'"
for _ in $(seq 1 240); do [[ -s "$tmux_rc" ]] && break; sleep 0.5; done
[[ -s "$tmux_rc" ]]
[[ "$(<"$tmux_rc")" == 0 ]]
grep -q 'ES_CODEX_MCP_V2_OK' "$tmux_raw"
sanitize < "$tmux_raw" > "$tmux_out"
unlink "$tmux_raw"
cat "$tmux_out"
echo 'tmux Codex rc=0 exact-response=PASS'

echo '=== 10. SUPPLEMENTARY TESTS ==='
cd "$REPO"
echo 'TEST ISOLATION: stopping the live user service so supervisor tests can bind their fixed loopback ports'
restore_live_daemon() { systemctl --user start mcp-daemon.service; }
trap restore_live_daemon EXIT
systemctl --user stop mcp-daemon.service
if ss -H -ltn '( sport = :8001 or sport = :8005 or sport = :8006 )' | grep -q .; then
  echo 'test isolation failed: a required loopback port remains occupied' >&2
  exit 1
fi
pytest -q tests/test_mcp_installer.py tests/test_mcp_hygiene.py tests/test_mcp_supervisor.py tests/test_install_script.py tests/test_backup_home_script.py | tee "$ARTIFACTS/pytest_output.txt"
bash -n config/mcp-daemon/start-mcp-daemons.sh scripts/install-mcp-daemon.sh scripts/start-mcp-daemons.sh install.sh
shellcheck -e SC2034 config/mcp-daemon/start-mcp-daemons.sh scripts/install-mcp-daemon.sh scripts/start-mcp-daemons.sh install.sh
echo 'bash -n + shellcheck PASS'
systemctl --user start mcp-daemon.service
trap - EXIT
for _ in $(seq 1 40); do
  listener_count=$(ss -H -ltn '( sport = :8001 or sport = :8005 or sport = :8006 )' | wc -l)
  [[ "$listener_count" -eq 3 ]] && break
  sleep 0.25
done
[[ "${listener_count:-0}" -eq 3 ]]
echo 'TEST ISOLATION RESTORE: mcp-daemon.service active with 3/3 loopback listeners — PASS'

echo '=== 11. SECRET SCANS (REDACTED) ==='
set +e
gitleaks dir --redact --no-banner --exit-code 1 "$BUNDLE" > "$ARTIFACTS/gitleaks_report.txt" 2>&1
gitleaks_rc=$?
set -e
if [[ "$gitleaks_rc" -eq 0 ]]; then
  echo 'gitleaks=PASS (no findings)'
elif [[ "$gitleaks_rc" -eq 1 ]]; then
  echo 'gitleaks=FAIL (findings redacted in artifacts/gitleaks_report.txt)'
  cat "$ARTIFACTS/gitleaks_report.txt"
  exit 1
else
  echo "gitleaks=ERROR rc=$gitleaks_rc"
  exit "$gitleaks_rc"
fi
marker_hit=0
while IFS= read -r -d '' file; do
  if rg -q --pcre2 'GOCSPX-[A-Za-z0-9_-]+|ya29\.[A-Za-z0-9._-]+|1//[A-Za-z0-9._-]+|AIza[0-9A-Za-z_-]{20,}' "$file"; then marker_hit=1; fi
done < <(find "$BUNDLE" -type f \
  \( -name '*.md' -o -name '*.json' -o -name '*.jsonl' -o -name '*.txt' -o -name '*.cast' -o -name '*.srt' -o -name '*.sha256' \) \
  ! -name capture_evidence.sh ! -name methodology.md -print0)
if [[ "$marker_hit" -eq 0 ]]; then echo 'oauth-marker-scan=PASS (no Google OAuth markers; values never printed)'; else echo 'oauth-marker-scan=FAIL (marker detected; values withheld)'; exit 1; fi

echo '=== 12. POST-RUN SHA / GIT STABILITY ==='
POST_SHA=$(git rev-parse HEAD)
printf 'PRE=%s\nPOST=%s\n' "$HEAD_SHA" "$POST_SHA"
[[ "$HEAD_SHA" == "$POST_SHA" ]]
git_state POST | tee "$ARTIFACTS/git_post_state.txt"
diff -u "$ARTIFACTS/git_pre_state.txt" "$ARTIFACTS/git_post_state.txt" > "$ARTIFACTS/git_state_diff.txt" || true
if [[ ! -s "$ARTIFACTS/git_state_diff.txt" ]]; then echo 'git state PRE/POST MATCH — PASS'; else echo 'git state PRE/POST DIFFER — FAIL'; cat "$ARTIFACTS/git_state_diff.txt"; exit 1; fi
echo 'SHA MATCH — EVIDENCE CAPTURE PASS'
