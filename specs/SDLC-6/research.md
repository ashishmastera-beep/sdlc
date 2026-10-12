# SDLC-6: Add Customer Tier (Gold, Silver, Bronze) to Account — Research specification

> Written by the enrichment agent before the functional and technical specs. It records what was found in the
> repository and why the chosen approach was picked, so reviewers can check the reasoning, not just the result.
> Every section is required. Write "None" rather than deleting a section.

## Request as understood

Account managers need an optional Account attribute to classify customers as Gold, Silver, or Bronze, and the team should be able to see that classification on Account records. The story does not identify the specific Account layouts or which users need edit versus read access; this specification assumes all current Account layouts should expose the field and separates field edit/read access with permission sets.

## What exists today

| Type | API name | Path | Relevance |
| --- | --- | --- | --- |
| Standard object | Account | Salesforce standard object; custom fields are represented under `force-app/main/default/objects/Account/` | The requested field belongs to Account. |
| Custom fields | Account.Contract_End_Date__c; Account.Renewal_Due__c | `force-app/main/default/objects/Account/fields/Contract_End_Date__c.field-meta.xml`; `force-app/main/default/objects/Account/fields/Renewal_Due__c.field-meta.xml` | Existing Account custom fields demonstrate field metadata and layout use; neither is Customer Tier. |
| Existing layout field | Account.CustomerPriority__c | Referenced in all four paths in the Page layouts row; no corresponding field definition is present under `force-app/main/default/objects/Account/fields/` | It is an existing, conceptually related Account field, but its definition and values are unavailable in source. Keep it unchanged; the story specifically asks for Gold/Silver/Bronze tiers. |
| Page layouts | Account-Account Layout; Account-Account (Sales) Layout; Account-Account (Marketing) Layout; Account-Account (Support) Layout | `force-app/main/default/layouts/Account-Account Layout.layout-meta.xml`; `force-app/main/default/layouts/Account-Account %28Sales%29 Layout.layout-meta.xml`; `force-app/main/default/layouts/Account-Account %28Marketing%29 Layout.layout-meta.xml`; `force-app/main/default/layouts/Account-Account %28Support%29 Layout.layout-meta.xml` | All are Account record layouts; each currently displays other Account fields. Add the tier to all four to keep the field visible regardless of assigned layout. |
| Permission sets | Sales_Contract_Editor; Sales_Contract_Viewer | `force-app/main/default/permissionsets/Sales_Contract_Editor.permissionset-meta.xml`; `force-app/main/default/permissionsets/Sales_Contract_Viewer.permissionset-meta.xml` | Existing permissionsets grant field access for contract fields only; their names and descriptions do not match customer-tier capability. |
| Account automation | None found | `force-app/main/default/triggers/` and `force-app/main/default/flows/` contain no Account trigger or flow metadata. | No existing Account automation needs coordination for a simple field addition. |
| Lightning record pages | None found | `force-app/main/default/flexipages/` has no files. | Current visible Account surfaces in source are page layouts; no Lightning page metadata is available to update. |
| Apex | None relevant found | `force-app/main/default/classes/` contains `PipelineHealthService` and its test, but no Account-specific classes. | A stored picklist and layout change need no Apex behavior. |

## Dependencies and impact

- Add one custom picklist field to the standard Account object and include it on all four source-controlled Account layouts. Leave the existing `CustomerPriority__c` field and its current behavior unchanged.
- Create dedicated field-access permission sets: an editor set for account managers and a read-only viewer set for the team. Users must receive the appropriate permission set for the field to be editable or readable; page-layout placement alone does not grant field access.
- The inspected Account layouts already display custom fields. The inspected source contains no Account trigger or flow that would react to tier changes.
- No record deletion, migration, integration, or existing field type change is required. Existing Accounts may remain blank because the field is optional.

## Options considered

| Option | How it works | Pros | Cons |
| --- | --- | --- | --- |
| A (chosen) | Add an optional, restricted Account picklist with the three requested values, place it on every current Account layout, and grant access through dedicated permission sets. | Stores the classification in a typed field, limits entry to the allowed values, and keeps UI visibility consistent across layouts with explicit least-privilege access. | Permission-set assignments are required for intended users. |
| B | Reuse the existing `CustomerPriority__c` layout field (or Account.Rating). | Avoids adding a field and may reuse a nearby concept. | `CustomerPriority__c` is present on all four layouts, but its definition and value set are not in the repository. The story names Gold/Silver/Bronze and calls for Customer Tier; reusing an existing field could conflate concepts or alter existing data and behavior. |

**Decision:** Choose Option A. Add a separate optional picklist for the explicitly requested Gold/Silver/Bronze tier and leave `CustomerPriority__c` unchanged unless product review establishes that it is the same business concept. This avoids changing existing Account semantics while all layouts and dedicated permissionsets provide a consistent, secure UI.

## Salesforce standards applied

The repository metadata instructions (`.github/instructions/metadata.instructions.md`) require custom-field description and help text, PascalCase field API names, and permission sets rather than profile edits. The `platform-custom-field-generate` skill requires those field attributes and a restricted picklist unless open-ended values are explicitly requested. The org standards (`.github/skills/org-salesforce-standards/SKILL.md`) specify `Customer_Tier__c`-style underscore naming and permission-set access. No Apex, trigger, or Flow is proposed, so the Apex USER_MODE, trigger-framework, and bulk-processing rules do not apply.

## Assumptions

- Customer Tier is a single-select picklist whose active labels and values are exactly Gold, Silver, and Bronze; no ordering, default, or additional values are required. Confirm during review if product expects a different ordering or defaults.
- Customer Tier is distinct from the existing layout field `CustomerPriority__c`; its definition and configured values are not available in source. Confirm the distinction during review; the recommended default is to add the requested field separately to avoid changing existing field usage.
- “Visible on the Account page” means available on each current Account page layout; no Lightning record page exists in this repository to update.
- Account managers receive edit access and other intended team viewers receive read-only access through dedicated permission sets. The release owner must assign these sets to the correct users; role/profile mappings are not present in source.

## References

- `.pipeline-input/issue.json`
- `.github/instructions/metadata.instructions.md`
- `.github/instructions/specs.instructions.md`
- `.github/skills/platform-custom-field-generate/SKILL.md`
- `.github/skills/org-salesforce-standards/SKILL.md`
- `force-app/main/default/objects/Account/fields/Contract_End_Date__c.field-meta.xml`
- `force-app/main/default/objects/Account/fields/Renewal_Due__c.field-meta.xml`
- `force-app/main/default/layouts/Account-Account Layout.layout-meta.xml`
- `force-app/main/default/layouts/Account-Account %28Sales%29 Layout.layout-meta.xml`
- `force-app/main/default/layouts/Account-Account %28Marketing%29 Layout.layout-meta.xml`
- `force-app/main/default/layouts/Account-Account %28Support%29 Layout.layout-meta.xml`
- `force-app/main/default/permissionsets/Sales_Contract_Editor.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Sales_Contract_Viewer.permissionset-meta.xml`
