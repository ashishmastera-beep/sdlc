# SDLC-6: Add Customer Tier (Gold, Silver, Bronze) to Account — Test plan

> Every acceptance criterion (AC1, AC2, …) maps to at least one test. Changed Apex classes need ≥ 85% coverage.

## Apex tests

None. This is a metadata-only change and introduces no Apex.

## LWC Jest tests

None. No LWC is changed.

## Flow tests

None. No Flow is changed.

## UAT steps

| Step | As (persona) | Do | Expect | Covers |
| --- | --- | --- | --- | --- |
| 1 | Account manager with `Account_Customer_Tier_Editor` | Create or edit an Account; select Gold, save, reopen, and repeat with Silver and Bronze | Each allowed value can be selected and saved, and the saved selection remains visible on the Account | AC1 |
| 2 | Account manager with `Account_Customer_Tier_Editor` | Create an Account with Customer Tier blank, then edit another Account to clear its tier and save | Both saves succeed and Customer Tier remains blank | AC2 |
| 3 | Account team viewer with `Account_Customer_Tier_Viewer` | Open Account records on each of the four current Account layouts (default, Sales, Marketing, Support) | Customer Tier is visible on each layout; viewer can read but not edit it | AC3 |
| 4 | Release administrator | Inspect field metadata and permissionset definitions after deployment | The picklist is restricted to Gold, Silver, Bronze; optional with no default; editor has read/edit FLS and viewer has read-only FLS | AC1, AC2, AC3 |

## Not tested automatically

Metadata deployment validation and end-user visibility/editability are verified in UAT rather than Apex or Jest, because the change contains no executable code. Step 4 verifies metadata configuration; steps 1–3 verify the user-facing acceptance criteria.
