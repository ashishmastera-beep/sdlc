# Connecting Jira and GitHub (Phase 4)

Only **two** Jira automation rules are needed. Everything else (retries, the WIP gate, PR and deploy status) runs on the GitHub side, which keeps Jira's monthly automation allowance for the human gates.

| What happens | Who moves the card | What fires |
| --- | --- | --- |
| Card dragged to **Enrichment In Progress** | Product owner / tech lead | Jira rule 1 → `jira.enrich` |
| Card dragged to **Enrichment Approved** | Tech lead | Jira rule 2 → `jira.spec_approved` |
| Approved spec moves to **Ready for Build** | `reconciler` (WIP gate) | GitHub dispatches `jira.build` itself |
| PR opened / approved / merged | `pr-sync` | GitHub → Jira REST |
| Merge validated in QA, release to production | `deploy-qa`, `release-prod` | GitHub → Jira REST |
| Lost event, dead run | `reconciler` every 15 min | GitHub re-dispatches |

## 1. GitHub → Jira: Jira API token

1. Sign in to Atlassian as the account the pipeline should act as (your own for testing; a dedicated `svc-pipeline` user later).
2. Open <https://id.atlassian.com/manage-profile/security/api-tokens> → **Create API token** (not "with scopes"), name it `sdlc-pipeline`, expiry 1 year.
3. In GitHub, **Settings → Secrets and variables → Actions → New repository secret**:
   - `JIRA_USER` = that account's email
   - `JIRA_API_TOKEN` = the token

`JIRA_BASE_URL` is not needed: it comes from `config/pipeline.json` (`https://ashishmastera.atlassian.net`).

## 2. Jira → GitHub: GitHub token for the rules

Create a fine-grained token at <https://github.com/settings/personal-access-tokens/new>:

- **Resource owner:** `ashishmastera-beep`; **Repository access:** Only `sdlc`
- **Permissions:** *Contents: Read and write* (this is what `repository_dispatch` needs). Nothing else.
- **Expiration:** 90 days (set a reminder)

You will paste it into the two rules below. It never goes into the repository.

## 3. The two Jira automation rules

In Jira: **SDLC project → Project settings → Automation → Create rule**. Build each rule exactly as below.

### Rule 1: Enrichment started

1. **Trigger:** *Work item transitioned* → To status: **Enrichment In Progress**
2. **Action:** *Edit work item fields* → **Agent State** = `Queued`
3. **Action:** *Send web request*
   - **Web request URL:** `https://api.github.com/repos/ashishmastera-beep/sdlc/dispatches`
   - **HTTP method:** POST
   - **Web request body:** Custom data
     ```json
     {"event_type": "jira.enrich", "client_payload": {"issue_key": "{{issue.key}}", "source": "jira"}}
     ```
   - **Headers** (tick *Hidden* on Authorization):
     | Name | Value |
     | --- | --- |
     | `Authorization` | `Bearer <your fine-grained token>` |
     | `Accept` | `application/vnd.github+json` |
     | `X-GitHub-Api-Version` | `2022-11-28` |
   - Tick **Delay execution of subsequent rule actions until we've received a response for this web request**
4. Name it `SDLC → GitHub: enrich`, turn it on.

Dragging a card back from **Enrichment Completed** to **Enrichment In Progress** (rework) fires the same rule; the stage works out that it is a rework.

### Rule 2: Spec approved

Same as rule 1, except:

- **Trigger:** To status **Enrichment Approved**
- **Body:** `{"event_type": "jira.spec_approved", "client_payload": {"issue_key": "{{issue.key}}", "source": "jira"}}`
- **Name:** `SDLC → GitHub: spec approved`

GitHub answers a successful dispatch with **HTTP 204**. Check the rule's **Audit log**: `401` means the token is wrong or expired, `404` means the token cannot see the repository.

## 4. Test the loop (Phase 4 acceptance)

With the stubs in place, no AI runs yet; each stage only proves the plumbing.

1. Create a story in SDLC, fill in **Acceptance Criteria**, move it to **Ready to Work**, then drag it to **Enrichment In Progress**.
2. Within a minute: Agent State goes Queued → Running → Idle, a comment links the GitHub run, and the card lands in **Enrichment Completed**.
3. Drag it to **Enrichment Approved**. Within a minute: **Approved Spec SHA** is filled, then the reconciler moves it to **Ready for Build** and the build stage moves it to **In Build**.
4. Open a PR titled `SDLC-<n>: test` → card goes to **PR Created** with **Build PR** filled. Merge it → **Approved**.
5. Run **release-prod** → card goes to **Released**.

Failure checks:
- Disable rule 1, drag a card to Enrichment In Progress and set Agent State = Queued by hand. Within 15 minutes the reconciler picks it up.
- Send the same event twice (re-run the router run): the second run is skipped as stale.
