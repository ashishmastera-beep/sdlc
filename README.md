# SDLC: AI-assisted Salesforce delivery pipeline

Salesforce source for the Jira **SDLC** project. Stories move from a Jira card to a production release with people doing three things: write and approve the story, approve the spec, approve the PR and the release. AI agents (GitHub Copilot) write specs and code in between; plain pipelines do every deployment.

Full design: *AI-Assisted Salesforce Delivery Pipeline — Design & Implementation Plan* (Claude doc).

## How a story flows

| Jira status | Who moves it | What happens |
| --- | --- | --- |
| Draft → Ready to Work | Product owner | Story has acceptance criteria |
| → Enrichment In Progress | Product owner / tech lead | Agent 1 writes `specs/<KEY>/` and opens a spec PR |
| → Enrichment Completed | Automation | Spec PR ready for review |
| → Enrichment Approved | Tech lead | Spec approved; spec PR merged |
| → Ready for Build → In Build | Automation (WIP-limited) | Copilot coding agent implements the spec |
| → PR Created → Approved | Automation | CI, Copilot review, spec check, then a human approves |
| → Deployed → Released | Pipelines | QA/UAT deploy, then approved production release |
| Blocked | Any automation | A human takes over; see the card's latest comment |

## Repository layout

```text
force-app/main/default/   Salesforce source (source format)
manifest/package.xml      Baseline retrieve manifest
specs/_templates/         Spec templates the enrichment agent fills in
specs/<KEY>/              One folder per Jira issue (functional, technical, test plan, log)
config/pipeline.json      Jira statuses, transitions, field IDs, limits, org aliases
scripts/jira/             Jira REST helpers used by the workflows
scripts/sf/               Salesforce CLI helpers used by the workflows
.github/copilot-instructions.md   Rules every Copilot agent follows
.github/instructions/     Path-specific rules (Apex, LWC, Flow, metadata, specs)
.github/skills/           Salesforce agent skills (forcedotcom/sf-skills, pinned) + org-* skills
.github/workflows/        Pipelines and agents
```

## Baseline (do this before any agent work)

The pipeline only works if `main` matches production.

1. Edit `manifest/package.xml` so it covers only metadata your team owns.
2. Set `sourceApiVersion` in `sfdx-project.json` and `<version>` in the manifest to your org's API version.
3. Retrieve and commit:
   ```bash
   sf org login web --alias prod
   sf project retrieve start --manifest manifest/package.xml --target-org prod
   git add force-app && git commit -m "Baseline from production"
   ```
4. Validate against QA: `sf project deploy validate --source-dir force-app --target-org qa --test-level RunLocalTests`.
5. From then on, change QA and production only through the pipeline.

## Pipelines (Phase 2)

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `pr-validate` | Every PR to `main` | `jira-key` (title starts with `SDLC-n:`), `static` (LWC lint, Jest, script tests, Code Analyzer), `sf-validate` (check-only deploy to QA with RunLocalTests + ≥85% coverage on changed classes) |
| `deploy-qa` | Merge to `main` touching `force-app/` | Deploys to QA. **Single-org mode: validates only**, because QA and production are the same org |
| `release-prod` | Manual (Actions → release-prod → Run workflow) | Validates against production, waits for approval on the `production` environment, quick-deploys, tags and publishes a GitHub release |

### Test mode: one Developer Edition org

`config/pipeline.json` has `"orgs": {"mode": "single-org"}`: the agent sandbox, QA and production all point to `https://orgfarm-f12f97ac86-dev-ed.develop.my.salesforce.com`. Real deployments happen only through `release-prod`, so the approval gate is still meaningful. To move to real sandboxes, give each role its own `instanceUrl`, set `"mode": "multi-org"`, and put each org's secrets in its GitHub Environment.

### One-time setup

1. **Key pair** (on your machine; never commit or paste the key anywhere else):
   ```bash
   openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes -keyout server.key -out server.crt -subj "/CN=sdlc-ci"
   ```
2. **External Client App** in the org (Setup → External Client App Manager → New): enable OAuth, scopes `api` and `refresh_token, offline_access`, enable **JWT Bearer Flow**, upload `server.crt`. In its policies set *Permitted Users* to *Admin approved users are pre-authorized* and add your profile or a permission set that includes the CI user.
3. **Repository secrets** (Settings → Secrets and variables → Actions → New repository secret):
   - `SF_CLIENT_ID`: the app's consumer key
   - `SF_USERNAME`: the CI user's username
   - `SF_JWT_KEY`: full contents of `server.key`
4. **Environments** (Settings → Environments): create `qa` (no rules) and `production` with *Required reviewers* = the release manager and *Deployment branches* = `main` only.
5. **Branch ruleset** on `main` once the first PR is green: require a pull request, 1 approval, and the status checks `jira-key`, `static`, `sf-validate`.

## Rules of the road

- Never move cards into **In Build** through **Released** by hand.
- Never change QA or production by hand.
- Changes to `.github/`, `config/` and `scripts/` need a platform lead's review (see `CODEOWNERS`).
- No secrets in the repo. Credentials live in GitHub Environment secrets.
