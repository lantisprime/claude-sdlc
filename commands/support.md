---
description: Start Phase 7 — add monitoring, logging, alerts, dashboards, and a runbook stub for the deployed change.
---

Invoke the `support` skill. Prerequisite: `.claude/sdlc/gates/deploy-<task-slug>.md`.

Produces platform-neutral artifacts when no observability platform is configured. Integrates via MCP when Grafana/Datadog/CloudWatch is wired up — but never auto-applies production alert changes.

Produces: logging deltas, metrics/alert config, dashboard JSON, runbook stub.

On completion, invoke the `gate-signoff` skill to capture the human sign-off via chat and write `.claude/sdlc/gates/support-<task-slug>.md`.
