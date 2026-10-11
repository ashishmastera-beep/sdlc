# SDLC-5: Track contract end date on Account and flag renewals due in 30 days — Test plan

> Every acceptance criterion (AC1, AC2, …) maps to at least one test. Changed Apex classes need ≥ 85% coverage.

## Apex tests

None. This is a metadata-only change with no Apex class.

## LWC Jest tests

None. No Lightning Web Component is changed.

## Flow tests

None. No Flow is changed.

## UAT steps

| Step | As (persona) | Do | Expect | Covers |
| --- | --- | --- | --- | --- |
| 1 | Sales representative with editor permission set and Account edit access | Open an Account, enter a contract end date, save, reopen, then change and save the date | The date is stored and remains editable by the authorized editor | AC1 |
| 2 | Intended Account viewer | View an Account with a contract end date of today, then one with a date exactly 30 days ahead | The renewal-due indicator is true for both boundary dates | AC2 |
| 3 | Intended Account viewer | View Accounts with contract end dates of yesterday, 31 days ahead, and blank | The renewal-due indicator is false in all three cases | AC3 |
| 4 | Intended Account viewer without editor permission set; authorized sales editor | View both fields and attempt to edit the date as the viewer; repeat the edit as the editor | The viewer can read both fields but cannot change the date; the editor can change it | AC4 |

## Not tested automatically

There is no Apex, Flow, or LWC behavior to exercise with existing automated test infrastructure. Verify formula boundary behavior and effective field-level access in an org through the UAT steps above. Confirm field visibility on each applicable assigned Account layout and check for independent edit grants before release.
