# SDLC-6: Add Customer Tier (Gold, Silver, Bronze) to Account — Technical specification

> Written by the enrichment agent. The build agent implements exactly this. Changes after approval go through the tech lead.
> Name only components that exist in `force-app/` (cite the path) or that are explicitly marked **NEW**.

## Summary of change

Add an optional restricted picklist on Account with exactly Gold, Silver, and Bronze, then expose it in every existing Account page layout. Dedicated field-permission sets provide edit access to account managers and read-only access to intended team viewers, avoiding reuse of the contract-specific permissionsets.

## Impacted metadata

| Type | API name | Path | Change (NEW / MODIFY / DELETE) | Notes |
| --- | --- | --- | --- | --- |
| CustomField | Account.Customer_Tier__c | `force-app/main/default/objects/Account/fields/Customer_Tier__c.field-meta.xml` | NEW | Label `Customer Tier`; optional restricted single-select picklist; Gold, Silver, Bronze; no default. Description: `Categorizes the Account's customer tier so the team can identify priority service customers.` Help: `Select Gold, Silver, or Bronze to indicate the customer's service tier. Leave blank if no tier is assigned.` |
| Layout | Account-Account Layout | `force-app/main/default/layouts/Account-Account Layout.layout-meta.xml` | MODIFY | Add Customer_Tier__c with Edit behavior to Account Information. |
| Layout | Account-Account (Sales) Layout | `force-app/main/default/layouts/Account-Account %28Sales%29 Layout.layout-meta.xml` | MODIFY | Add Customer_Tier__c with Edit behavior to Account Information. |
| Layout | Account-Account (Marketing) Layout | `force-app/main/default/layouts/Account-Account %28Marketing%29 Layout.layout-meta.xml` | MODIFY | Add Customer_Tier__c with Edit behavior to Account Information. |
| Layout | Account-Account (Support) Layout | `force-app/main/default/layouts/Account-Account %28Support%29 Layout.layout-meta.xml` | MODIFY | Add Customer_Tier__c with Edit behavior to Account Information. |
| PermissionSet | Account_Customer_Tier_Editor | `force-app/main/default/permissionsets/Account_Customer_Tier_Editor.permissionset-meta.xml` | NEW | Grant readable and editable FLS to Customer_Tier__c; assign to account managers. |
| PermissionSet | Account_Customer_Tier_Viewer | `force-app/main/default/permissionsets/Account_Customer_Tier_Viewer.permissionset-meta.xml` | NEW | Grant readable, non-editable FLS to Customer_Tier__c; assign to intended Account team viewers. |

## Data model changes

Add Account.Customer_Tier__c, label `Customer Tier`, type Picklist, optional (`required=false`), with a restricted inline value set containing exactly Gold, Silver, and Bronze in that order. Do not set a default. Set description to `Categorizes the Account's customer tier so the team can identify priority service customers.` and inline help to `Select Gold, Silver, or Bronze to indicate the customer's service tier. Leave blank if no tier is assigned.` No relationship, record type, or migration is required.

## Automation

None. No Account trigger or Flow was found in the source repository, and the story requires no automation.

## Security model

- Sharing: No change to Account record sharing.
- CRUD / FLS: No new object CRUD permissions. Grant readable and editable field-level access only through `Account_Customer_Tier_Editor`; grant readable and non-editable field-level access through `Account_Customer_Tier_Viewer`. Do not edit profiles. Salesforce's normal UI field permission enforcement applies; no Apex access path is introduced.
- Permission sets to create or update: Create `Account_Customer_Tier_Editor` and `Account_Customer_Tier_Viewer`. Release owner assigns them to the intended users.

## Governor limits and bulk behaviour

None. This metadata-only change adds no Apex, SOQL, DML, or asynchronous processing.

## Integrations

None.

## Deployment

- Order or dependencies: Deploy the Account field before the layouts and permission sets that reference it; they may then be deployed together.
- Destructive changes: None.
- Manual steps (pre- or post-deploy): 1. Assign `Account_Customer_Tier_Editor` to account managers and `Account_Customer_Tier_Viewer` to the intended read-only audience. 2. Confirm the assignments match the product owner's approved audience before release.

## Rollback

Redeploy the previous layouts and remove the new permission sets' assignments. Because the field is new, leave it in place if any values have been entered; if removal is required, export or otherwise preserve populated values and perform field deletion through a separate destructive release.

## Risks and open questions

- Users without field read access will not see Customer Tier even when it is on their assigned layout → assign the viewer or editor permission set to every intended reader.
- Exact audience for the editor and viewer permissions is not defined in the story or existing source → release owner confirms user assignments before production deployment.
- `CustomerPriority__c` is already referenced on all four layouts, but its field definition and values are absent from source → add the requested tier as a distinct field and do not change the existing field pending product confirmation.
