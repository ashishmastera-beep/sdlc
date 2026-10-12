# SDLC-7: Record a contact's preferred contact method — Functional specification

> Written by the enrichment agent from the Jira story. Reviewed and approved by the product owner and tech lead (gate G2).
> Every section is required. Write "None" rather than deleting a section.

## Problem

Sales representatives currently have no structured Contact field to record whether a person prefers Email, Phone, or WhatsApp. This makes the preference difficult to capture consistently and use when deciding how to reach the person.

## Users and personas

| Persona | Salesforce profile / permission set | What they need |
| --- | --- | --- |
| Sales representative | Existing Contact record access plus the proposed `Sales_Contact_Editor` permission set | View and set a Contact's preferred channel |
| Other Contact user | Existing Contact access; no new field permission unless separately granted | No additional edit access is required by this story |

## Scenarios

1. A sales representative opens a Contact they can edit, selects Email, Phone, or WhatsApp as the preferred contact method, and saves the Contact.
2. A sales representative leaves the preference blank when no preference is known and saves the Contact.
3. A sales representative views a Contact and can see the field on the Contact page.

## Acceptance criteria

Restated from Jira as testable Given / When / Then. Each criterion gets an ID used by the test plan.

| ID | Given | When | Then |
| --- | --- | --- | --- |
| AC1 | A sales representative can edit a Contact and has the new field permission | They choose Email, Phone, or WhatsApp and save | The selected value is saved on the Contact, and the field offers only those three choices |
| AC2 | A sales representative can edit a Contact | They leave Preferred Contact Method blank and save | The Contact saves successfully with the field blank |
| AC3 | A sales representative can view a Contact using the layout assigned to sales users | They open the Contact page | Preferred Contact Method is visible on the page |

## Out of scope

- Sending messages, changing outreach behavior, or automatically using the preference in an integration or campaign.
- Making the field required, selecting a default value, or allowing values outside the three listed choices.
- Creating or changing Contact sharing rules, Contact CRUD permissions, or profile definitions.
- Capturing consent or opt-in status for any communication channel.

## Open questions

- OQ1: Which Contact page layout is assigned to the intended sales representatives in the target org?
  Recommended answer: Use the standard `Contact-Contact Layout` unless org configuration shows that sales representatives use a different layout; confirm its assignment before deployment because no Contact layouts are present in this repository.
