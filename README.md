# Portable shared MCP evidence bundle — iteration 3

Start with [`evidence.md`](evidence.md), then verify [`checksums.sha256`](checksums.sha256). Machine-readable scenario results are in [`run.json`](run.json); provenance and runtime identifiers are in [`metadata.json`](metadata.json); `request_responses.jsonl` is an assembled index of the submitted initialize payloads and retained responses, while the primary curl response headers and bodies are under `artifacts/`; terminal recordings and inspected frames (51 extracted PNGs under `recordings/frames/`, with representative copies at the top level) are under `recordings/`.

This bundle is sanitized and records one Linux host and the three named MCP endpoints only. Public clean-machine reproduction instructions and media are linked from `evidence.md`; publication does not turn the single-host recording into a second-machine execution claim.

Capture command: `capture_evidence.sh` (recorded via asciinema). The script performs pre/post SHA and repository-state checks, direct listener PID/cgroup/service proof, real MCP initialize calls, a real tmux Codex turn, 72 focused tests (including the supervisor module under controlled fixed-port isolation), shell checks, and redacted gitleaks/OAuth-marker scans.
