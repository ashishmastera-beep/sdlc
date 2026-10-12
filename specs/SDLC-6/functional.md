# SDLC-6: Add Customer Tier (Gold, Silver, Bronze) to Account — Functional specification

> Written by the enrichment agent from the Jira story. Reviewed and approved by the product owner and tech lead (gate G2).
> Every section is required. Write "None" rather than deleting a section.

## Problem

Account managers currently have no dedicated Account field to identify a customer's service tier. The team needs a consistent, visible Gold/Silver/Bronze classification to recognize priority customers.

## Users and personas

| Persona | Salesforce profile / permission set | What they need |
| --- | --- | --- |
| Account manager | Proposed `Account_Customer_Tier_Editor` permission set; exact Salesforce profile is not identified in source | Choose and update an optional tier for an Account. |
| Account team viewer | Proposed `Account_Customer_Tier_Viewer` permission set; exact Salesforce profile is not identified in source | Read the tier from the Account record page. |

## Scenarios

1. An account manager opens or creates an Account, chooses Gold, Silver, or Bronze in Customer Tier, and saves; the saved tier is displayed on the Account page for users with read access.
2. An account manager leaves Customer Tier blank and saves the Account; the record remains valid and the field is blank.

## Acceptance criteria

Restated from Jira as testable Given / When / Then. Each criterion gets an ID used by the test plan.

| ID | Given | When | Then |
| --- | --- | --- | --- |
| AC1 | An account manager has edit access to an Account | They set Customer Tier to Gold, Silver, or Bronze and save | The selected value is accepted and remains on the Account. |
| AC2 | An account manager creates or edits an Account | They leave Customer Tier blank and save | The Account saves successfully with Customer Tier blank. |
| AC3 | An Account is displayed using any current Account page layout, and the user has read access to Customer Tier | The user opens the Account record page | Customer Tier is visible on the page. |

## Out of scope

- Automatically assigning a tier, calculating priority, or changing service behavior based on the tier.
- Adding tier values beyond Gold, Silver, and Bronze, setting a default, or requiring a tier.
- Adding the tier to unrelated objects, reports, list views, integrations, or Lightning record pages.
- Changing Account sharing, object permissions, profiles, or existing field behavior.

## Open questions

- OQ1: Which existing users should receive edit and read access to Customer Tier?
  - Recommended answer: assign the proposed editor permission set to account managers and the proposed read-only viewer permission set to the broader intended Account team; exact user assignments should be confirmed by the release owner because no role-to-permission mapping exists in source.
- OQ2: Should Customer Tier be separate from the existing Account.CustomerPriority__c field shown on the current layouts?
  - Recommended answer: keep Customer Tier separate and leave CustomerPriority__c unchanged. Its metadata/value definition is not in source and the request explicitly specifies Gold, Silver, and Bronze; product can confirm if these represent the same business concept.
