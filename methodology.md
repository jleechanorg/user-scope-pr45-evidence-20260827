# Methodology

This is Layer 2 real-callstack evidence captured on the target Linux machine against live user services and the real installed Codex CLI. `capture_evidence.sh` recorded the repository and remote SHA, pre/post porcelain status, tracked-file index digest, diff-index/worktree/cache checks, selected credential-free source changes, systemd/cgroup state, loopback listeners, a direct listener-PID → `/proc/PID/cgroup` → `mcp-daemon.service` check, systemd process tree, raw MCP initialize requests/responses, client configuration, a fresh Codex turn inside tmux, focused tests, shell lint, and redacted secret scans.

The terminal session was captured as asciicast, rendered to GIF, encoded to MP4 with burned-in captions, and sampled at one frame per second with `ffmpeg`. Sample frames were visually inspected. Paths, session identifiers, and potential credential values are sanitized or withheld. The explicit Google OAuth marker scan checks for common `GOCSPX-`, `ya29.`, `1//`, and `AIza...` forms without printing matching values.

The evidence is local-only. It has not been published as a gist, release asset, or PR attachment.
