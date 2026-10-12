# SDLC-7: Record a contact's preferred contact method — Technical specification

> Written by the enrichment agent. The build agent implements exactly this. Changes after approval go through the tech lead.
> Name only components that exist in `force-app/` (cite the path) or that are explicitly marked **NEW**.

## Summary of change

Add an optional, restricted Contact picklist with the exact values Email, Phone, and WhatsApp. Give sales representatives read/edit field access through a dedicated permission set and place the field on the Contact page layout used by those representatives; no code or automation is needed.

## Impacted metadata

| Type | API name | Path | Change (NEW / MODIFY / DELETE) | Notes |
| --- | --- | --- | --- | --- |
| CustomField | Contact.Preferred_Contact_Method__c | `force-app/main/default/objects/Contact/fields/Preferred_Contact_Method__c.field-meta.xml` | **NEW** | Optional restricted picklist; values Email, Phone, WhatsApp; no default |
| PermissionSet | Sales_Contact_Editor | `force-app/main/default/permissionsets/Sales_Contact_Editor.permissionset-meta.xml` | **NEW** | Grants read/edit FLS to the field; assign only to intended sales representatives |
| Layout | Contact-Contact Layout | `force-app/main/default/layouts/Contact-Contact Layout.layout-meta.xml` | **NEW** | No Contact layout exists in source; retrieve and amend the layout assigned to sales reps if it already exists in the org rather than creating a duplicate. Add the field with Edit behavior. |

## Data model changes

Add `Contact.Preferred_Contact_Method__c` (custom Picklist, optional, restricted, values exactly `Email`, `Phone`, `WhatsApp`, no default value). It has no relationship, formula, or backfill requirement. Use a meaningful description and inline help text. Contact is a Salesforce standard object; only the custom field metadata is added.

## Automation

None. The field stores a user-selected preference and has no requested side effects.

## Security model

- Sharing: Standard Contact sharing remains unchanged; no sharing model or record access changes are part of this story.
- CRUD / FLS: No Apex is introduced. Salesforce UI enforces the user's existing Contact CRUD and the new field-level security. The proposed permission set grants readable and editable access to the custom field; it must be assigned only to the intended sales representatives.
- Permission sets to create or update: Create **NEW** `Sales_Contact_Editor`; do not edit profiles or repurpose `Sales_Contract_Editor`, which is limited to Account contract fields.

## Governor limits and bulk behaviour

Not applicable. This metadata-only change adds no Apex, Flow, SOQL, DML, asynchronous work, or transaction-level processing.

## Integrations

None. WhatsApp is a picklist value only; this story does not connect to WhatsApp or another messaging service.

## Deployment

- Order or dependencies: Deploy the custom Contact field, then the permission set referencing it, then the Contact layout referencing it.
- Destructive changes: None. Rollback must not delete the field after user data has been entered; field deletion/data removal, if ever required, is a separate destructive change.
- Manual steps (pre- or post-deploy):
  1. Before deployment, identify/retrieve the Contact layout assigned to sales representatives and amend that layout if its actual name differs from the proposed standard `Contact-Contact Layout`.
  2. After deployment, assign `Sales_Contact_Editor` to the intended sales representatives and verify they have the Contact layout with the field.

## Rollback

Remove the field from the Contact layout and revoke/remove the field permission grant first. Retain the field metadata if it contains saved values; deleting the field and its data requires a separately approved destructive release.

## Risks and open questions

- The target Contact layout and its assignments are absent from source → confirm the layout used by sales representatives before deployment; amend the assigned layout so the field is actually visible.
- The permission set grants edit access to Contact preference data → assign it only to intended sales representatives and keep existing Contact sharing/CRUD unchanged.
- OQ1: Confirm whether the standard `Contact-Contact Layout` is assigned to intended sales representatives; if not, use the assigned layout instead. Recommended default: the standard Contact layout because no alternative Contact layout is represented in source.
