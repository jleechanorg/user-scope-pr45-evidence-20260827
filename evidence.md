# Evidence report: portable shared MCP on Linux (iteration 3)

## Outcome

At commit `5049740121308881add6db4fd09af4c53f014073`, the target Linux machine showed an active shared `mcp-daemon.service`, three loopback MCP listeners, successful real initialize exchanges for Context7/sequential-thinking/Slack, a successful real Codex turn inside tmux, and 72 focused tests passing. The capture completed with identical pre/post SHA and clean canonical repository state. No credential values were captured; gitleaks and an explicit Google OAuth marker scan reported no findings.

## Claim → Artifact Map

| Claim | Layer / source | Artifact and key field | Result |
|---|---|---|---|
| Shared daemon is active and owns the three expected loopback listeners | [Layer 2 real-OS/systemd+cgroup] | `artifacts/systemd_service.txt` (`ActiveState=active`, `MainPID`), `artifacts/listeners.txt` (127.0.0.1:8001/8005/8006), `artifacts/launcher_status.txt` | PASS |
| Each listener PID belongs to the service cgroup and process tree | [Layer 2 real-OS/procfs+cgroup] | `artifacts/listener_pid_cgroup_service.txt` (`listener_pid`, `/proc/PID/cgroup`, `service-cgroup-match=PASS`), `artifacts/systemd_process_tree.txt` | PASS |
| Context7, sequential-thinking, and Slack accept MCP initialize | [Layer 2 real-HTTP/MCP] | `request_responses.jsonl` has one raw request and HTTP 200 JSON-RPC result for each service; per-service headers/bodies retained | PASS |
| Codex CLI lists the shared trio; Claude strict MCP configuration names the trio, while Claude CLI lists Slack | [Layer 2 real-CLI/config] | `artifacts/codex_mcp_list.txt` lists context7/sequential-thinking/slack; `artifacts/claude_strict_names.txt` names the trio; `artifacts/claude_mcp_list.txt` lists Slack | PASS |
| Agent settings and cgroup memory ceilings are unlimited | [Layer 2 real-CLI/OS] | `artifacts/codex_agents_block.txt`, `artifacts/agents_slice.txt`, `artifacts/cgroup_limits.txt` | PASS |
| A fresh real Codex CLI turn works inside tmux | [Layer 2 real-CLI/real-LLM] | `artifacts/tmux_codex_output.txt` contains exact `ES_CODEX_MCP_V2_OK`; `artifacts/tmux_codex_rc.txt` is `0` | PASS |
| Focused regression tests pass and capture does not mutate source | [Layer 1 focused tests + Layer 2 repository-state] | `artifacts/pytest_output.txt` (`72 passed`, including `tests/test_mcp_supervisor.py`), `artifacts/git_pre_state.txt`, `artifacts/git_post_state.txt`, empty `artifacts/git_state_diff.txt`, terminal cast | PASS |
| Bundle contains no detected secrets or Google OAuth markers | [Layer 2 capture-hygiene/tooling] | `artifacts/gitleaks_report.txt`; terminal output records `gitleaks=PASS` and `oauth-marker-scan=PASS` without printing values | PASS |

## Visual evidence

- `recordings/terminal-evidence.cast`: raw terminal event stream of the capture.
- `recordings/terminal-evidence.gif`: rendered terminal playback.
- `recordings/terminal-evidence.mp4`: captioned/burned-in terminal playback.
- `recordings/terminal-evidence.srt`: caption source.
- `recordings/frame-02.png`, `frame-18.png`, `frame-30.png`: extracted frames inspected from the MP4; all paths and credentials are sanitized.

## What this proves

- The installed configuration worked on this Linux machine at the recorded time and commit.
- The real service owned the expected listeners, and each listener PID's `/proc/PID/cgroup` matched `mcp-daemon.service`.
- The three raw protocol initialize exchanges returned HTTP 200 JSON-RPC results.
- The actual Codex CLI completed the recorded tmux turn, and the focused 72-test suite passed, including 19 supervisor tests run with the live service briefly stopped and automatically restored to avoid fixed-port collisions.
- Pre/post SHA, tracked-file digest, diff-index, worktree, and cache checks remained unchanged and clean.

## What this evidence does NOT prove

- It does not prove behavior under long-duration load, resource exhaustion, or network failure.
- It does not prove a clean install on another machine or on macOS; `/mac` was intentionally untouched.
- It does not test WorldAI or Aside MCP, which were unavailable and skipped.
- It does not prove that all possible MCP clients or endpoints behave identically; only the three named live endpoints were exercised.
- It does not itself prove a second-machine execution. Clean-machine reproduction instructions and public downloadable artifacts are published below, but the recorded runtime remains this Linux host.

## Public reproduction and media

- Clean-machine reproduction gist: https://gist.github.com/jleechan2015/cdec09831b02b9f0a30f86b9c51a17af
- Public evidence repository: https://github.com/jleechanorg/user-scope-pr45-evidence-20260827
- Inline terminal GIF: https://raw.githubusercontent.com/jleechanorg/user-scope-pr45-evidence-20260827/main/terminal-evidence.gif
- Downloadable MP4: https://github.com/jleechanorg/user-scope-pr45-evidence-20260827/releases/download/pr45-iteration-003/terminal-evidence.mp4
- Source PR: https://github.com/jleechanorg/user_scope/pull/45
