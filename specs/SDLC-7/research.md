# SDLC-7: Record a contact's preferred contact method — Research specification

> Written by the enrichment agent before the functional and technical specs. It records what was found in the
> repository and why the chosen approach was picked, so reviewers can check the reasoning, not just the result.
> Every section is required. Write "None" rather than deleting a section.

## Request as understood

A sales representative needs an optional Contact field with the controlled choices Email, Phone, or WhatsApp, so representatives can record and use a person's preferred channel. The field must be available on the Contact page. The story does not specify exact Contact page-layout assignments or which sales users should receive field-level access.

## What exists today

| Type | API name | Path | Relevance |
| --- | --- | --- | --- |
| Standard object | Contact | Salesforce standard object; no Contact object or field metadata file exists under `force-app/main/default/objects/` | Target record for the new field |
| Custom field | Account.Contract_End_Date__c | `force-app/main/default/objects/Account/fields/Contract_End_Date__c.field-meta.xml` | Existing optional field metadata demonstrates field description and help text conventions |
| Custom field | Account.Renewal_Due__c | `force-app/main/default/objects/Account/fields/Renewal_Due__c.field-meta.xml` | Existing formula-field metadata; unrelated business logic |
| Permission set | Sales_Contract_Editor | `force-app/main/default/permissionsets/Sales_Contract_Editor.permissionset-meta.xml` | Grants sales representatives field access to Account contract fields only; no Contact field access |
| Permission set | Sales_Contract_Viewer | `force-app/main/default/permissionsets/Sales_Contract_Viewer.permissionset-meta.xml` | Read-only access to Account contract fields only |
| Page layouts | Account-Account Layout and Account-specific Marketing, Sales, Support layouts | `force-app/main/default/layouts/` | Four Account layouts exist; no Contact layout metadata exists to update |
| Automation | No Contact automation found | `force-app/main/default/flows/.gitkeep`, `force-app/main/default/triggers/.gitkeep` | No flows or triggers are present in the repository |
| Apex | PipelineHealthService | `force-app/main/default/classes/PipelineHealthService.cls` | Unrelated smoke-test service; no Contact business logic exists |

Looked in `force-app/main/default/objects/`, `layouts/`, `permissionsets/`, `flows/`, `triggers/`, and `classes/`; the repository contains no Contact-specific field, layout, permission set, Flow, trigger, or Apex component.

## Dependencies and impact

- Adds one optional custom picklist field to the standard Contact object with the three exact choices from the story.
- Contact field-level access must be granted to intended sales representatives. The existing `Sales_Contract_Editor` grants Account contract access only and is not an appropriate Contact permission grant.
- The field must be placed on the Contact layout used by sales representatives. No Contact layout source or page-layout assignment is present in this repository, so the exact target needs confirmation during implementation/review.
- No Contact automation is present in the repository; the field is descriptive data and does not require a trigger, Flow, Apex, or integration.
- Other Contact users should not receive edit access merely by default. Use a permission set, not profile edits, for the required sales access.

## Options considered

| Option | How it works | Pros | Cons |
| --- | --- | --- | --- |
| A (chosen) | Add an optional restricted custom picklist to Contact; grant sales edit access with a dedicated permission set; display it on the Contact layout used by sales reps | Matches the explicit options, supports empty values, and uses Salesforce metadata/FLS without unnecessary automation | The repository does not identify or contain the target Contact layout or the sales-user assignment |
| B | Store the preferred channel in free text or as a Contact note | Avoids defining a field picklist | Does not enforce the three allowed values and is not directly available as a consistent Contact field |

**Decision:** Use a restricted picklist, because the story defines a closed set of three values, and leave it optional. Deliver the requested UI through a Contact layout and permission set; implementation must use the Contact layout assigned to sales users in the target org rather than editing profiles.

## Salesforce standards applied

- `.github/skills/platform-custom-field-generate/SKILL.md`: include meaningful field description/help text, use a valid custom field API name, and make a closed-choice picklist restricted.
- `.github/instructions/metadata.instructions.md`: add custom fields to permission sets rather than profiles; include field description and help text; avoid unrelated object metadata.
- `.github/skills/org-salesforce-standards/SKILL.md` and `.github/copilot-instructions.md`: use naming conventions; grant access through permission sets; use `WITH USER_MODE` and `AccessLevel.USER_MODE` only if server-side data access is introduced. No server-side code is needed for this request.
- `.github/instructions/specs.instructions.md`: cite existing components or mark additions NEW, restate ACs as testable statements, and map every AC to tests.

## Assumptions

- The field is single-valued and optional; blank is valid — based on "whether" and "field is optional" in the story.
- The picklist values are exactly `Email`, `Phone`, and `WhatsApp`; no default value is selected because none was requested.
- Use the standard Contact page-layout presentation for sales representatives; identify the actual assigned Contact layout in the target org before deployment because the repository contains no Contact layout or assignment.
- A dedicated sales Contact editor permission set is appropriate for granting the requested edit access; the relevant sales user population/assignment is confirmed by the product owner or Salesforce administrator.
