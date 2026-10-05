# SDLC-2: Pipeline smoke test — Technical specification

## Summary of change

Add a tiny Apex service and its test so the pipeline can be proven end to end: PR validation against the org with RunLocalTests, the coverage gate, merge, and an approved production release.

## Impacted metadata

| Type | API name | Path | Change | Notes |
| --- | --- | --- | --- | --- |
| ApexClass | PipelineHealthService | force-app/main/default/classes/PipelineHealthService.cls | NEW | `with sharing`, no SOQL/DML |
| ApexClass | PipelineHealthServiceTest | force-app/main/default/classes/PipelineHealthServiceTest.cls | NEW | Covers both branches |

## Data model changes

None.

## Automation

None.

## Security model

- Sharing: `with sharing`; the class touches no data.
- CRUD / FLS: not applicable (no data access).
- Permission sets: none.

## Governor limits and bulk behaviour

No queries or DML.

## Integrations

None.

## Deployment

- Order or dependencies: none
- Destructive changes: None
- Manual steps: None

## Rollback

Delete both classes in a follow-up destructive PR once the pipeline is trusted.

## Risks and open questions

- None.
