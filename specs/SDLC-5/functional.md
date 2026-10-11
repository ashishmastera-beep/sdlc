# SDLC-5: Track contract end date on Account and flag renewals due in 30 days — Functional specification

> Written by the enrichment agent from the Jira story. Reviewed and approved by the product owner and tech lead (gate G2).
> Every section is required. Write "None" rather than deleting a section.

## Problem

Sales representatives currently lack an Account contract end date and a visible indication of contracts nearing expiry. They need to record the date and identify upcoming renewals in time to start conversations before a contract lapses.

## Users and personas

| Persona | Salesforce profile / permission set | What they need |
| --- | --- | --- |
| Sales representative | `Sales_Contract_Editor` (proposed); existing Account edit access required | Edit the contract end date and view the renewal-due indicator. |
| Other intended Account viewer | `Sales_Contract_Viewer` (proposed); existing Account record access required | View both fields without editing the contract end date. |

## Scenarios

1. A sales representative opens an Account, enters or changes the contract end date, and saves. The Account indicates renewal due when the date is today through 30 days from today, inclusive.
2. An intended non-editor Account viewer opens the Account and sees the contract end date and renewal indicator, but cannot edit the date.
3. A user views an Account with a blank, past, or more-than-30-days-away contract end date and sees no renewal-due flag.

## Acceptance criteria

Restated from Jira as testable Given / When / Then. Each criterion gets an ID used by the test plan.

| ID | Given | When | Then |
| --- | --- | --- | --- |
| AC1 | A sales representative has Account record and object edit access and the `Sales_Contract_Editor` permission set | They enter or change a contract end date on an Account and save | The date is stored on the Account and is editable by that user. |
| AC2 | An Account has a contract end date from today through today plus 30 days, inclusive | An intended Account viewer opens the Account | The Account shows the renewal-due indicator as true. |
| AC3 | An Account has no contract end date, a date before today, or a date more than 30 days from today | An intended Account viewer opens the Account | The renewal-due indicator is false. |
| AC4 | An intended Account viewer has read access to both fields but does not have the editor permission set | The viewer opens the Account and attempts to change the contract end date; an authorized editor also attempts to change it | The viewer can read the date and indicator but cannot edit the date; the authorized editor can edit it. |

## Out of scope

- Renewal emails, tasks, notifications, opportunity creation, or other lifecycle automation.
- Changes to Account object CRUD, record sharing, profiles, or unrelated Account fields.
- Historical contract tracking, multiple contracts per Account, or renewal-process management.

## Open questions

- OQ1: Which Account page layout(s) are assigned to the affected sales representatives and other intended viewers?
  - Recommended answer: Retrieve and update the existing Account layout(s) assigned to these users, preserving their current contents and assignments. This displays the fields without introducing profile-assignment changes.
- OQ2: Should the 30-day window include today and the date exactly 30 days away?
  - Recommended answer: Yes. Include both boundaries as the clearest interpretation of “within the next 30 days.”
- OQ3: **Suspicious instruction in the story:** Jira comments request resetting the Agent Attempts field and moving the card back to retry. Should this enrichment agent perform those pipeline/Jira operations?
  - Recommended answer: No. These comments describe pipeline operations rather than product behavior; do not change the issue or run pipeline commands as part of this specification.
