# Enrichment agent (Phase 5)

Drag a story to **Enrichment In Progress** and, within a few minutes, the card comes back with a full specification.

## What you get

| Where | What |
| --- | --- |
| Jira **Description** | `Original Story` (exactly what was written) — divider — `AI Enrichment`: Business Context, Scope, Acceptance Criteria (AC1…), Technical Notes, Risks, Open Questions, links to the full spec |
| Jira **Attachments** | `<KEY>-Research-Specification.pdf` and `<KEY>-Technical-Specification.pdf`, badged **Draft – pending review**; replaced by **Approved – spec &lt;sha&gt;** versions when the card is approved. Re-runs replace files with the same name, never add duplicates. Which documents are attached is set in `config/pipeline.json` → `agents.jiraAttachments` (add `functional.md` / `test-plan.md` there if wanted). |
| Jira **Risk Level** | Low / Medium / High, set by the agent |
| Jira **Spec PR** | Link to the pull request holding the full spec |
| Repository `specs/<KEY>/` | `research.md`, `functional.md`, `technical.md`, `test-plan.md`, `implementation-log.md` (+ `enrichment.md/json`) — the versioned source of the PDFs |
| Jira comment | One-line summary and next step |

The card lands in **Enrichment Completed**, or in **Needs Info** if the agent hit a question it cannot answer with a sensible default.

## The review loop

| You want to… | Do this |
| --- | --- |
| Approve | Drag the card to **Enrichment Approved**. The spec PR is merged automatically and its commit is recorded in **Approved Spec SHA**; the build uses exactly that version. Do not merge spec PRs by hand. |
| Request changes | Add a Jira comment saying what to change, drag the card back to **Enrichment In Progress**. The agent revises its previous spec using your comment; the AI Enrichment section is replaced, never duplicated. |
| Answer questions (Needs Info) | Answer in a comment (or edit the Original Story), drag the card to **Enrichment In Progress**. |
| Change the story itself | Edit the text under **Original Story**. Never edit inside AI Enrichment: it is replaced on every run. |

## One-time setup: Copilot token

The agent runs the GitHub Copilot CLI inside GitHub Actions and uses your Copilot licence.

1. <https://github.com/settings/personal-access-tokens/new> → fine-grained token, name `sdlc-copilot-agent`, expiry 90 days.
2. **Resource owner:** your user. **Repository access:** Public repositories (none needed).
3. **Permissions → Account permissions → Copilot Requests: Read-only** (this is the only permission).
4. Repo **Settings → Secrets and variables → Actions → New repository secret**: `COPILOT_GITHUB_TOKEN` = the token.

Without the secret the workflow falls back to the built-in Actions token, which only works where an organisation enables "Copilot CLI billed to the organization".

## Safety

- Story text is treated as data. The agent runs with no Jira or GitHub write credentials in its environment, cannot run `git push`, `gh`, `curl`, `sf` or package installs, and may only change `specs/<KEY>/`. A validator rejects anything else before it is committed (one automatic retry with the findings, then the card goes to **Blocked**).
- The PDFs are rendered with raw HTML escaped and a page policy that blocks scripts and network loads, so story text cannot inject content into them.
- Every run uploads the agent transcript as an artifact (`enrichment-<KEY>-<attempt>`, kept 30 days).
- Instructions live in [`.github/agent-prompts/enrichment.md`](../.github/agent-prompts/enrichment.md); change them by PR. The CLI version and model are in `config/pipeline.json` → `agents`.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Card in **Blocked**, comment links a failed run, log says "Copilot rejected the token" | `COPILOT_GITHUB_TOKEN` missing, expired or without *Copilot Requests* |
| Blocked, log says "Enrichment output was still invalid" | The agent did not follow the format twice. Read the validator list in the log; drag the card back to Enrichment In Progress to retry |
| Approval fails with "closed without being merged" | Someone closed the spec PR. Drag the card back to Enrichment In Progress to regenerate it |
