# Logger template

The logging module is a concrete starting point for developers to refactor around their existing Salesforce schema. Its Apex, trigger, and tests live in `force-app/main/default/classes/logging/<role>` and the standard trigger directory. Object definitions and permission sets belong to the consuming application and are deliberately omitted.

Deploying the core now requires the sample logging schema, or a corresponding adaptation of the logger source. Query and HTTP remain independent of logging; none of these modules calls another.

## Adapt the schema

The sample uses `LogEvent__e` as a high-volume platform event with **Publish Immediately**, and `Log__c` as the stored diagnostic record. Both must exist before validating or deploying the Apex. The event may be delivered before the producer commits, so persistence must use event payloads rather than querying uncommitted application records.

| Field              | Event type               | Stored log type   | Sample contract                               |
| ------------------ | ------------------------ | ----------------- | --------------------------------------------- |
| `Level__c`         | Text(20)                 | Picklist          | `INFO`, `WARN`, `DEBUG`, `ERROR`              |
| `Message__c`       | Long Text(32768)         | Long Text(32768)  | Caller-sanitized diagnostic text              |
| `Source__c`        | Text(50)                 | Text(50)          | Component name                                |
| `Operation__c`     | Text(50)                 | Text(50)          | Defaults to `UNSPECIFIED`                     |
| `RecordId__c`      | Text(18)                 | Text(18)          | Optional Salesforce identifier                |
| `ExceptionType__c` | Text(50)                 | Text(50)          | Optional Apex exception type                  |
| `StackTrace__c`    | Long Text(32768)         | Long Text(32768)  | Optional exception stack                      |
| `TransactionId__c` | Text(50)                 | Required Text(50) | Producer request ID                           |
| `UserId__c`        | Text(18)                 | Lookup(User)      | Producer identity, not subscriber identity    |
| `OccurredAt__c`    | Date/Time                | Date/Time         | Producer timestamp                            |
| `Status__c`        | Text(20)                 | Text(20)          | Defaults to `New`                             |
| `EventUuid__c`     | Not a custom event field | Text(36)          | Maps the platform-generated event `EventUuid` |

Stored text fields must accommodate the event field lengths. The sample assumes the existing log name field accepts inserts without an explicitly supplied `Name`; adapt the mapping if your object requires a name or other mandatory fields. Keep stored logs private and limit visibility to trusted operators.

When adapting:

1. Rename `LogEvent__e` and `Log__c` throughout the module, tests, and trigger declaration. Update their ownership names in `config/modules.json`.
2. Adapt event construction in `LoggerService`, event permission checks in `LogEventPublisher`, and database mapping in `LogEventTriggerService.fromEvent`. Update the `EventUuid__c` uniqueness check and duplicate-error field name together.
3. Review the trigger context guard in `LogEventStore`, then rename Apex components and their companion metadata files if these global names already belong to another feature. Keep one trigger per object.
4. Adapt the test factory, required-field failure fixture, severity vocabulary, field-length assertions, and usage example to the same schema.
5. Supply publisher/reader permissions and validate the adapted production code and tests together against a development org with that schema.

For cross-delivery deduplication, the consuming application must make its stored UUID field unique. The sample skips repeated nonblank UUIDs inside one batch and recognizes duplicate insert failures only when the UUID field is unique and the error identifies that field. With a nonunique UUID field, repeated deliveries can create additional records. Check existing data before introducing uniqueness; this feature does not change fields or clean up historical logs.

## Use the logger

```apex
LoggerService logger = LoggerService.fromSource('AccountImport');
logger.info('Import started');
logger.error('Import rejected', 'IMPORT', accountId);
LogFlushResult result = LoggerService.flushWithResult();
```

See [the usage example](../examples/logging/logger.apex). Existing `info` and `error` overloads are retained. The enum retains all four schema severity values; the convenience methods currently enqueue `INFO` and `ERROR`.

All instances share one transaction-local buffer. Logging calls enqueue events; they do not publish automatically. Flush explicitly at an application-owned boundary. Validate identifiers before enqueueing, and sanitize messages and exceptions before passing them to the logger. Exception messages and stacks are stored as supplied, subject to truncation; this template cannot identify application-specific secrets or personal data.

`flushWithResult()` returns `acceptedCount`, `rejectedCount`, and ordered `outcomes` containing `eventUuid`, `accepted`, and sanitized `errorCodes`. Accepted entries leave the buffer; rejected entries remain available for an explicit retry within the same transaction. Retrying does not resend accepted entries. The void `flush()` shares this behavior and emits only a rejected-request count on handled failures.

A successful publish result means the request was queued, not that the event was finally published or stored. No callback, automatic publish retry, durable failure queue, or delivery guarantee is provided. Pending entries disappear when the transaction ends. Publish Immediately permits already-published diagnostics to outlive a producer rollback. Governor-limit exceptions remain outside the best-effort error handling. See [Salesforce publishing semantics](https://developer.salesforce.com/docs/platform/platform-events/guide/platform-events-publish-callbacks.html).

## Permissions and persistence boundary

Supply a permission set such as `LoggerPublish` with create access to the event. Grant event read access separately to subscribers that need it. The publisher explicitly checks event create access before publishing. Platform event fields do not support field-level security, so the entire payload is available to authorized subscribers; sanitize it before enqueueing. This grant should not give publishers read or write access to stored logs. See [Salesforce platform event considerations](https://developer.salesforce.com/docs/platform/platform-events/guide/platform-events-considerations.html).

Supply a separate permission set such as `LoggerRead` with read access to the stored log object and fields, including visibility across private records where needed for trusted operators. Keep create, edit, and delete access disabled. Production code checks effective event create permission, not a particular permission-set name. Stored-log readers must use user-mode queries to enforce object and field access.

The subscriber runs under the platform event execution identity. `LogEventStore` intentionally inserts in `SYSTEM_MODE` so a producer does not need stored-log CRUD. Its guard accepts only the actual `LogEvent__e` after-insert trigger batch. `LogEventTriggerService.save()` cannot be used as a direct database logging API. The pure `fromEvent()` mapping remains callable without persistence privileges. Review this boundary when adapting the feature.

The sink performs one partial-success bulk insert. Permanent row failures do not prevent valid rows from being saved. Row locks request at most three batch retries; throwing `EventBus.RetryableException` rolls back that attempt's DML. At exhaustion, the sink reports sanitized error counts/codes and keeps the successful rows from the final attempt. Fallback diagnostics never recursively publish logs. See [Salesforce retry behavior](https://developer.salesforce.com/docs/platform/platform-events/guide/platform-events-subscribe-apex-refire.html).

## Validate

Tests create their own minimum-access users and temporary permission grants; production permission sets need not already exist. The factory assumes the `Minimum Access - Salesforce` profile and a Salesforce user license. Update that fixture for a different org licensing model.

```sh
npm test
npm run analyze:core
npm run validate:core -- --target-org dev
```

Validation uploads all local source and tests as a check-only deployment. The logger tests exercise 251 buffered events, a full 2,000-event batch at the persistence boundary with partial success, real event delivery of a 252-event mixed batch, event mapping, field limits, explicit publish retries, duplicate-error classification, access denial, reader isolation, and the trusted persistence guard. Simulated platform results cover transient failures that cannot be produced reliably in a unit test. Actual cross-delivery deduplication requires the consuming application's unique UUID constraint.

Apex tests permit publication of at most 500 event messages per test. The 2,000-event case therefore calls the private, test-visible persistence boundary; the smaller delivery tests verify the actual trigger path.
