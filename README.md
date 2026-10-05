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

## Rules of the road

- Never move cards into **In Build** through **Released** by hand.
- Never change QA or production by hand.
- Changes to `.github/`, `config/` and `scripts/` need a platform lead's review (see `CODEOWNERS`).
- No secrets in the repo. Credentials live in GitHub Environment secrets.
