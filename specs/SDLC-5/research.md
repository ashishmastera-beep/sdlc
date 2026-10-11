# SDLC-5: Track contract end date on Account and flag renewals due in 30 days — Research specification

> Written by the enrichment agent before the functional and technical specs. It records what was found in the
> repository and why the chosen approach was picked, so reviewers can check the reasoning, not just the result.
> Every section is required. Write "None" rather than deleting a section.

## Request as understood

Sales representatives need to record an Account's contract end date and recognize when it is approaching so they can begin renewal conversations before expiry. All intended Account viewers should be able to see the date, but editing it should be limited to users granted the sales editor permission set. The story does not define the exact inclusivity of the 30-day boundary; this specification treats today through today plus 30 days, inclusive, as due.

## What exists today

| Type | API name | Path | Relevance |
| --- | --- | --- | --- |
| Standard object metadata source | Account | `force-app/main/default/objects/.gitkeep` | The standard Account object is the target; this repository has no Account object or field metadata. |
| Custom fields | None | `force-app/main/default/objects/.gitkeep` | No Account contract date or renewal field is present. |
| Permission sets | None | `force-app/main/default/permissionsets/.gitkeep` | No sales or viewer permission set is tracked to extend. |
| Layouts | None | `force-app/main/default/layouts/.gitkeep` | No Account layout is tracked to add the fields to or to identify current layout assignments. |
| Triggers | None | `force-app/main/default/triggers/.gitkeep` | No trigger is present; date-derived behavior does not require one. |
| Flows | None | `force-app/main/default/flows/.gitkeep` | No Flow is present; date-derived behavior does not require one. |
| Apex service and test | `PipelineHealthService`, `PipelineHealthServiceTest` | `force-app/main/default/classes/PipelineHealthService.cls`, `force-app/main/default/classes/PipelineHealthServiceTest.cls` | Pipeline smoke-test code only; neither references Account, contracts, or renewal behavior. |
| Lightning Web Components | None | `force-app/main/default/lwc/.gitkeep` | No component is present; no custom UI is needed for this field-and-formula change. |

The metadata directories listed above contain only `.gitkeep` files; no relevant Account metadata is tracked in `force-app/main/default/`.

## Dependencies and impact

- Add an optional Date field to Account and a formula Checkbox that derives whether the date is today through 30 days from today, inclusive.
- Add both fields to the Account page layout(s) used by the affected users. The repository does not identify those layouts, so the target org's current layout assignments must be inspected and the existing layout metadata preserved when brought into source.
- Grant field-level read/edit access through permission sets: edit for the sales editor set and read-only for intended Account viewers. No permission set is present in source, and assignment to the intended users is a deployment/admin step.
- Permission grants are additive. Existing profile, permission-set, or other effective grants must be checked so users outside the sales editor group do not independently receive edit access. This change does not alter Account object CRUD or record sharing.
- No Account trigger, Flow, layout, permission set, or contract field currently exists in repository source. The only Apex service/test found is unrelated pipeline health code.

## Options considered

| Option | How it works | Pros | Cons |
| --- | --- | --- | --- |
| A (chosen) | Add a Date field and formula Checkbox on Account; expose them on the affected Account layout(s); grant FLS through narrowly scoped editor and viewer permission sets. | Declarative and directly derived from the date; the flag stays current as time passes without scheduled processing; least runtime complexity. | Target layouts, permission-set assignments, and effective access must be confirmed in the org because they are not tracked here. |
| B | Use a record-triggered Flow or Apex to maintain a stored Boolean flag. | Stores the flag as a record value. | The value becomes stale as days pass unless scheduled automation updates it; adds processing and maintenance for a value directly derived from a date. |

**Decision:** Use a formula Checkbox so Salesforce recalculates the due state using the current date, and no trigger, Flow, Apex, or scheduled job is needed. Use permission sets for field access and update the Account layout(s) already used by the intended users rather than creating an unassigned layout.

## Salesforce standards applied

- `.github/copilot-instructions.md`: grant access through permission sets rather than editing profiles; Apex sharing and CRUD/FLS rules are not applicable because no Apex is proposed.
- `.github/instructions/metadata.instructions.md`: use `Contract_End_Date__c`, add field description/help text, and grant new field access through permission sets.
- `.github/skills/org-salesforce-standards/SKILL.md`: use `<Area>_<Capability>` permission set naming and never edit profiles; proposed names are `Sales_Contract_Editor` and `Sales_Contract_Viewer`.
- `.github/skills/platform-custom-field-generate/SKILL.md`: include meaningful field descriptions and actionable help text; formula field type is its result type and formula content must be valid Salesforce formula syntax.
- `.github/skills/platform-permission-set-generate/SKILL.md`: use least-privilege FLS, omit unnecessary object/system permissions, and keep formula fields non-editable.

## Assumptions

- “Within the next 30 days” includes today and the date exactly 30 days after today. The formula and UAT boundary cases use this interpretation; the product owner can revise it before approval.
- The story's “sales permission set” means a purpose-specific `Sales_Contract_Editor` permission set if no suitable existing set is present in the target org. Intended non-editing Account users will receive `Sales_Contract_Viewer` or equivalent read-only FLS.
- “Others can view it” means users who already have Account record access and are assigned read access to both fields; this story does not expand Account record sharing.
- The current Account layouts assigned to intended users will be retrieved and updated, preserving unrelated layout content. The exact layout name(s) are unknown because none are tracked here.
- Jira comments report pipeline failures and include a request to reset the Agent Attempts field and move the card back to retry. These comments are not product requirements and no Jira changes are made by this agent.

## References

- `.pipeline-input/issue.json`
- `.github/copilot-instructions.md`
- `.github/instructions/metadata.instructions.md`
- `.github/instructions/specs.instructions.md`
- `.github/skills/org-salesforce-standards/SKILL.md`
- `.github/skills/platform-custom-field-generate/SKILL.md`
- `.github/skills/platform-permission-set-generate/SKILL.md`
- `force-app/main/default/objects/.gitkeep`
- `force-app/main/default/permissionsets/.gitkeep`
- `force-app/main/default/layouts/.gitkeep`
- `force-app/main/default/triggers/.gitkeep`
- `force-app/main/default/flows/.gitkeep`
- `force-app/main/default/classes/PipelineHealthService.cls`
- `force-app/main/default/classes/PipelineHealthServiceTest.cls`
