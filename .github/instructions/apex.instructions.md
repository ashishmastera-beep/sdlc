---
applyTo: "force-app/**/*.cls,force-app/**/*.trigger"
---

# Apex rules

## Design

- Triggers contain no logic: one trigger per object that calls its handler (`<Object>TriggerHandler`).
- Keep selectors (SOQL), services (business logic) and handlers separate; no SOQL in handlers' loops.
- Use `Database.*` methods with `AccessLevel.USER_MODE` for DML, or `insert as user`.
- Queries use `WITH USER_MODE` and bind variables; never build SOQL by string concatenation with user input.
- Prefer `Queueable` over `@future`; chain at most one Queueable per transaction unless the spec says otherwise.
- Catch exceptions only where you can handle them; never swallow them silently.

## Tests

- Test class name: `<ClassName>Test`; annotate with `@IsTest`; no `SeeAllData=true`.
- Create data with a test data factory, not inline in every method.
- Cover: happy path, bulk (200 records), negative/validation, and a user without access (`System.runAs`).
- Use `Assert.areEqual` / `Assert.isTrue` with a message on every assertion.
- Use `Test.startTest()` / `Test.stopTest()` around the code under test.

## Review checklist (code review agent)

Flag as **blocking**: SOQL/DML in loops, missing sharing keyword, missing CRUD/FLS enforcement, hard-coded IDs, tests without assertions, `SeeAllData=true`.
