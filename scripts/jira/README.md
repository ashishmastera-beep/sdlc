# Jira helper scripts

Used by the GitHub workflows. All need `JIRA_BASE_URL`, `JIRA_USER`, `JIRA_API_TOKEN` (the `svc-pipeline` account) plus `curl` and `jq`. Field IDs and status names come from `config/pipeline.json`.

| Script | Purpose |
| --- | --- |
| `get-issue.sh KEY` | Compact JSON of the issue (summary, description, AC, risk, latest comments) for agents |
| `transition.sh KEY "Status"` | Move to a status by name; no-op if already there |
| `comment.sh KEY "text" [url]` | Add a comment (one paragraph per line, optional link) |
| `set-field.sh KEY fieldKey value` | Set a pipeline field (`agentState`, `specPr`, `buildPr`, `agentRun`, `agentAttempts`, `approvedSpecSha`, `riskLevel`) |
| `guard.sh KEY "Expected Status"` | Outputs `proceed=true/false`: skips stale events and duplicate runs |
| `claim.sh KEY RUN_URL` | Agent State=Running, record run, attempts+1; blocks when over the limit |
| `release.sh KEY [--reset-attempts]` | Agent State=Idle after success |
| `block.sh KEY "reason" [url]` | Agent State=Failed, comment, move to Blocked |

Run the offline tests with `scripts/jira/test/run.sh` (uses a local mock of the Jira API).
