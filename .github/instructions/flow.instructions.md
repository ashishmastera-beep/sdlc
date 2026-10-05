---
applyTo: "force-app/**/flows/**"
---

# Flow rules

- Record-triggered Flows: use before-save for same-record field updates; after-save only for related records or actions.
- Entry conditions are always set; never run a Flow on every save without criteria.
- No Get Records, Create, Update or Delete elements inside loops; collect, then act once.
- Every Flow has a fault path on elements that can fail, ending in a logged error.
- One record-triggered Flow per object per trigger context where practical; order with Trigger Order.
- Description is filled on the Flow and on every non-obvious element.
- Do not mix a Flow and an Apex trigger on the same object and event unless `technical.md` says why.
