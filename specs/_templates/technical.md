# <KEY>: <summary> — Technical specification

> Written by the enrichment agent. The build agent implements exactly this. Changes after approval go through the tech lead.
> Name only components that exist in `force-app/` (cite the path) or that are explicitly marked **NEW**.

## Summary of change

<Two or three sentences: the approach, and why it was chosen over the obvious alternative.>

## Impacted metadata

| Type | API name | Path | Change (NEW / MODIFY / DELETE) | Notes |
| --- | --- | --- | --- | --- |
| ApexClass | | force-app/main/default/classes/... | | |

## Data model changes

<Objects, fields (type, length, required, default), relationships, record types. "None" if none.>

## Automation

<Triggers (via the org trigger framework), Flows (record-triggered vs screen, entry criteria), scheduled or async jobs.>

## Security model

- Sharing: <with sharing / inherited sharing, and why>
- CRUD / FLS: <how enforced: WITH USER_MODE, Security.stripInaccessible, permission set changes>
- Permission sets to create or update: <names>

## Governor limits and bulk behaviour

<How the change behaves for 200 records in one transaction; SOQL/DML counts; async boundaries.>

## Integrations

<Callouts, Named Credentials, platform events. "None" if none.>

## Deployment

- Order or dependencies: <e.g. field before Flow>
- Destructive changes: <None, or list them; destructive changes ship in a separate release>
- Manual steps (pre- or post-deploy): <None, or numbered steps; the release is blocked until each is ticked>

## Rollback

<How to undo: redeploy previous tag; data fixes needed; anything not reversible.>

## Risks and open questions

- <Risk> → <mitigation>
