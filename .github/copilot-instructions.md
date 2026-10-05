# Repository instructions for all Copilot agents

This is a Salesforce (Apex, LWC, Flow, metadata) codebase in source format under `force-app/`. Work arrives from Jira project SDLC; every change implements exactly one Jira key and its approved spec in `specs/<KEY>/`.

## Always

- Bulkify: no SOQL or DML inside loops; code must handle 200 records per transaction.
- Apex classes use `with sharing` unless `technical.md` says otherwise and explains why.
- Enforce CRUD and FLS: `WITH USER_MODE` in SOQL, `AccessLevel.USER_MODE` / `Security.stripInaccessible` for DML.
- One trigger per object, logic in a handler class (see `.github/skills/org-salesforce-standards`).
- No hard-coded record IDs, URLs, usernames or credentials; use Custom Metadata, Custom Labels or Named Credentials.
- Grant access with permission sets, never by editing profiles.
- Every Apex change ships with tests that assert behaviour (positive, negative, bulk, permission), not just coverage.
- Follow the Salesforce skills in `.github/skills/` for generating Apex, LWC, Flow, objects, fields and permission sets.

## Never

- Edit `.github/`, `config/`, `scripts/`, `sfdx-project.json` or `.forceignore`.
- Edit `specs/<KEY>/functional.md` or `specs/<KEY>/technical.md` after approval. If the spec is wrong, stop and say so in a PR comment.
- Disable, skip or weaken tests, Code Analyzer rules or coverage thresholds.
- Put secrets, tokens or production data in code, tests, comments or logs.

## Pull requests

- Title starts with the Jira key: `SDLC-12: <summary>`.
- Description lists each acceptance criterion (AC1, AC2, …) and the test that covers it.
- Append a dated entry to `specs/<KEY>/implementation-log.md`.
