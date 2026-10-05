# Specs

One folder per Jira issue: `specs/<KEY>/` (for example `specs/SDLC-12/`), created by the enrichment agent from `specs/_templates/`.

| File | Written by | Changed after approval by |
| --- | --- | --- |
| `functional.md` | Agent 1 | Tech lead only |
| `technical.md` | Agent 1 | Tech lead only |
| `test-plan.md` | Agent 1 | Agent 2 may add tests; nothing removed |
| `implementation-log.md` | Every stage (append-only) | Everyone, append only |
| `questions.md` | Agent 1, only when the story is unclear | Closed when the PO answers |

The spec version used for a build is the commit SHA stored in the Jira field **Approved Spec SHA**.
