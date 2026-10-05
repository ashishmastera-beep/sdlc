---
applyTo: "force-app/**/lwc/**"
---

# Lightning Web Components rules

- Use Lightning Data Service (`lightning/uiRecordApi`, `lightning-record-*-form`) before writing Apex.
- Apex called from LWC is `@AuraEnabled(cacheable=true)` for reads, enforces sharing and FLS, and returns DTOs, not raw SObjects with extra fields.
- Use SLDS classes and base components; no inline styles, no direct DOM manipulation outside `this.template`.
- Handle errors visibly (toast or inline message) and never leave a spinner running on failure.
- Labels shown to users come from Custom Labels.
- Every component has a Jest test in `__tests__/` covering render, user interaction and the error path.
- Accessibility: every interactive element has a label; keyboard navigation works.
