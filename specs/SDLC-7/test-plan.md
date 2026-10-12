# SDLC-7: Record a contact's preferred contact method — Test plan

> Every acceptance criterion (AC1, AC2, …) maps to at least one test. Changed Apex classes need ≥ 85% coverage.

## Apex tests

None. No Apex is added or changed.

## LWC Jest tests

None. No LWC is added or changed.

## Flow tests

None. No Flow is added or changed.

## UAT steps

| Step | As (persona) | Do | Expect | Covers |
| --- | --- | --- | --- | --- |
| 1 | Sales representative with `Sales_Contact_Editor` | In a test/sandbox Contact, choose each of Email, Phone, and WhatsApp in turn and save; inspect the available choices | Each listed choice is available and saves on the Contact; no unlisted value is offered | AC1 |
| 2 | Sales representative with `Sales_Contact_Editor` | Leave Preferred Contact Method blank on a test/sandbox Contact and save | The Contact saves and the field remains blank | AC2 |
| 3 | Sales representative with `Sales_Contact_Editor` | Open a Contact using the layout assigned to sales users | Preferred Contact Method is present and visible on the Contact page | AC3 |

## Not tested automatically

No Apex, LWC, or Flow test is applicable. Verify picklist metadata, permission-set field access, actual Contact layout assignment, and rendered field visibility through deployment validation and the UAT steps above; the repository contains no existing automated metadata/UI test harness for Contact layouts.
