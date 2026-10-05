---
applyTo: "force-app/**/objects/**,force-app/**/permissionsets/**,force-app/**/customMetadata/**,force-app/**/layouts/**"
---

# Metadata rules

- Custom fields have a description and help text; API names are PascalCase with no abbreviations (`Contract_End_Date__c`).
- New fields are added to a permission set, never to profiles.
- Do not change a field's type, length or required flag on existing data without a migration step in `technical.md`.
- Deleting fields or objects only in a separate PR labelled `destructive`.
- Custom Metadata records hold configuration that differs per environment only when the value is the same name in every org.
