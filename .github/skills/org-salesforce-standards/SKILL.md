---
name: org-salesforce-standards
description: This org's Salesforce conventions — naming, trigger framework, test data factory and permission model. Use whenever writing, reviewing or specifying Apex, triggers, objects, fields or permission sets in this repository.
---

# Org Salesforce standards

These rules override generic guidance from other skills when they conflict.

## Naming

| Item | Pattern | Example |
| --- | --- | --- |
| Apex class | PascalCase, role suffix | `AccountService`, `AccountSelector`, `AccountTriggerHandler` |
| Test class | `<Class>Test` | `AccountServiceTest` |
| Trigger | `<Object>Trigger` | `AccountTrigger` |
| Custom field | Words joined with underscores, no abbreviations | `Contract_End_Date__c` |
| Permission set | `<Area>_<Capability>` | `Sales_Contract_Editor` |
| LWC | camelCase | `contractSummary` |
| Flow | `<Object>_<When>_<What>` | `Case_AfterSave_NotifyOwner` |

## Trigger framework

One trigger per object, all events, delegating to a handler:

```apex
trigger AccountTrigger on Account (before insert, before update, after insert, after update, before delete, after delete, after undelete) {
    new AccountTriggerHandler().run();
}
```

The handler extends `TriggerHandler` and overrides only the contexts it needs (`beforeInsert`, `afterUpdate`, …). If `TriggerHandler` does not exist yet in `force-app/main/default/classes/`, the technical spec must list it as **NEW** and include a bypass switch read from Custom Metadata (`Trigger_Setting__mdt.Is_Active__c`) so a trigger can be disabled in an emergency without a deployment.

## Layers

- `*Selector` classes own SOQL (always `WITH USER_MODE`).
- `*Service` classes own business logic and DML.
- Handlers, controllers and Flows call services; they never query or write directly.

## Test data

Use `TestDataFactory` (create it as **NEW** if missing). Methods return unsaved records by default and take a `Boolean doInsert` flag.

## Access

New objects and fields are granted through permission sets named in the technical spec; profiles are never edited.
