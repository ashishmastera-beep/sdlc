# Build agent (Phase 6)

When an approved spec reaches **Ready for Build** (the WIP gate moves it there when a build slot is free), the build
agent implements it and opens a pull request that has already been validated in the org.

## What happens

| Step | Detail |
| --- | --- |
| 1. Start | Card → **In Build**. The pipeline checks that `specs/<KEY>/` on `main` is still exactly the approved spec (**Approved Spec SHA**); if someone changed it, the build stops. |
| 2. Org context | Read-only copies of the page layouts of every object the spec names (and which profile uses which layout) are retrieved into `.pipeline-input/org/`, so the agent edits the real layout instead of guessing. |
| 3. Build | GitHub Copilot CLI implements `technical.md` under `force-app/` (metadata, Apex and tests), following the Salesforce skills and org rules, appends a **Build** row to the Implementation Log and writes the PR description (every AC mapped to a test or UAT step). |
| 4. Local checks | Only `force-app/` and the log may change; no profiles; specs untouched; log append-only; XML well-formed; Apex comes with `@IsTest` classes; no hard-coded record IDs; copied layouts keep all their fields; no secrets. One automatic retry with the findings. |
| 5. Org validation | Check-only deploy to the org with `RunLocalTests` and the 85% coverage gate on changed classes. **On failure the errors go back to the agent: up to 2 fix rounds.** |
| 6. PR | Commit to `copilot/<KEY>`, open or update the PR titled `<KEY>: <summary>`, start the PR checks. |
| 7. Jira | **Build PR** set, card → **PR Created**, comment, updated **Implementation Log** PDF attached. |

Then a person reviews the PR. Approving it moves the card to **Approved**; merging deploys to QA (Phase 4 flow).

If no round passes, the card goes to **Blocked** with a link to the run; the job summary shows the last org errors.
Fix the spec or the org and drag the card back to **Ready for Build** (via Blocked).

## Safety

- The agent steps receive only `COPILOT_GITHUB_TOKEN`. Salesforce logins exist only inside `scripts/sf/with-org.sh`,
  which logs out and deletes the CLI's stored credentials when the command ends. Jira and GitHub write tokens are
  only in the steps that need them. `run-build.sh` refuses to start if any of them is present.
- The agent cannot run `git push`, `gh`, `curl`, `sf`, `npm` or other network commands.
- Every run keeps the agent transcripts, the validation feedback and `deploy-result.json` as an artifact (30 days).

## Settings

`config/pipeline.json` → `agents.build.model` (empty = Copilot's default). Instructions:
[`.github/agent-prompts/build.md`](../.github/agent-prompts/build.md).
The number of fix rounds (2) is fixed in `.github/workflows/stage-build.yml`.

## Copilot plan

The build runs the Copilot CLI inside GitHub Actions, so it works on **Copilot Free** within its monthly allowance;
GitHub's hosted Copilot coding agent (not used here) needs a paid plan. A build uses several agent requests
(one per round and retry), so watch usage at <https://github.com/settings/copilot>.
