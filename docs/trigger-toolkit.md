# Trigger toolkit

The independent `trigger` module adds three API 67.0 classes: `AbstractTriggerHandler`, `TriggerContext`, and `TriggerToolkitException`. It owns no objects, installs no object triggers, and has no dependencies. Its synchronous dispatcher follows Salesforce guidance on [thin triggers and bulk processing](https://developer.salesforce.com/blogs/2022/01/drive-consistency-and-grow-developer-skills-with-a-developer-best-practices-checklist) and [native context availability](https://trailhead.salesforce.com/content/learn/modules/apex_triggers/apex_triggers_intro).

## Handler contract

An object trigger invokes `new AccountTriggerHandler().run()`. `run()` captures `Trigger.operationType` and dispatches exactly one callback. Calling `run()` or `TriggerContext.current()` outside a trigger throws `TriggerToolkitException`. Handler exceptions propagate unchanged.

Extend `AbstractTriggerHandler` with explicit sharing and override only the callbacks you need. All callbacks are `protected virtual` with no-op defaults. Lists are `List<SObject>` and maps are `Map<Id, SObject>`; cast inputs inside the override to the concrete object type. See the [Account example](../examples/trigger/AccountTriggerHandler.cls).

| Callback                       | Arguments, in order                        |
| ------------------------------ | ------------------------------------------ |
| `beforeInsert`                 | new records                                |
| `beforeUpdate`, `afterUpdate`  | new records, new map, old records, old map |
| `beforeDelete`, `afterDelete`  | old records, old map                       |
| `afterInsert`, `afterUndelete` | new records, new map                       |

The protected `context` property has a private setter. Each invocation replaces it with its own context. The public context metadata (`operation`, `batchSize`, `objectType`) also has private setters. Subclasses can read the context without replacing it.

## Native collections

`getNewRecords()`, `getNewMap()`, `getOldRecords()`, and `getOldMap()` return the original native references. An unavailable getter throws a descriptive exception identifying the collection and operation. The toolkit never fabricates a map or old record.

| Event          | New list | New map | Old list | Old map |
| -------------- | -------- | ------- | -------- | ------- |
| Before insert  | Yes      | No      | No       | No      |
| Before update  | Yes      | Yes     | Yes      | Yes     |
| Before delete  | No       | No      | Yes      | Yes     |
| After insert   | Yes      | Yes     | No       | No      |
| After update   | Yes      | Yes     | Yes      | Yes     |
| After delete   | No       | No      | Yes      | Yes     |
| After undelete | Yes      | Yes     | No       | No      |

Before-insert/update edits affect the original records. After-event records and old records retain Salesforce's read-only restrictions. `addError()` remains attached to the native record and participates in normal DML rollback or partial-success behavior. No serialization, cloning, or collection reconstruction occurs in production code. A context is intended for its synchronous invocation; retaining it does not create a portable asynchronous payload.

## Field changes

Call `context.getChangedRecords(Account.Name)` in either update event. It compares each new record against the old map by ID and returns changed new record references in new-list order. Both null-to-value and value-to-null transitions count as changes; equal values and null pairs do not. The result list is new, while its records are native references. Comparisons use Apex value equality, including its string comparison semantics.

Null fields, fields from another object (even with the same API name), and non-update events throw `TriggerToolkitException`. This method compares the current new values at the time of the call, including earlier before-trigger edits. It performs no queries or field reads outside the supplied records. It does not grant field permissions; consuming services own their access boundary.

## Application responsibilities

Use one trigger per object and explicitly order service calls within each callback. Keep business rules idempotent: Salesforce can re-enter triggers during automation and partial-success retries. Every invocation runs fully; there are no static suppression flags or automatic recursion controls.

Bulkify consuming services, bind values, validate identifiers, and explicitly use user-mode queries/DML for application data. The toolkit performs no SOQL, DML, callouts, or permission elevation, and it does not catch business exceptions. Sharing declarations do not themselves enforce object or field permissions. Document any intentional system-mode boundary in the consuming service. The logging subscriber remains independent and is not routed through this framework.

Version 1 excludes bypass controls, metadata-based action registration, asynchronous callbacks, and platform-event/CDC specialization.

## Verification

Core tests use private `@TestVisible` seams for synthetic contexts. They cover all seven dispatch paths, no-op defaults, availability errors, concrete casts, reference identity, field comparisons, exception identity, repeated invocations, and zero queries/DML. No public context injection API is exposed.

The [opt-in integration fixtures](../examples/trigger/README.md) validate candidate core source and real triggers together in a temporary project. They exercise 251 records, repeated updates, native read-only records, delete/undelete, and partial-success `addError()` handling. Run core checks and both check-only validations before a PR; no persistent org deployment is needed.
