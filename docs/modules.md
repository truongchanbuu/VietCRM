# Module contracts

## Boundaries

Production source is `force-app/main/default`. Classes belong to `classes/<module>/<role>`. Only add roles actually used; no empty service/domain/DTO scaffolding. Metadata objects retain Salesforce's required `objects/<api-name>/fields` shape, with module ownership in `config/modules.json`.

Modules must not import business examples or archive classes. Explicitly declare any new module dependency in the registry and add an integration test for it. Do not build a universal base class hierarchy: prefer small interfaces at real substitution boundaries.

## Query

The compiler validates field paths and operators and creates bind values. Services orchestrate execution; strategies implement paging. QueryLocator is separate because Batch Apex owns its chunk lifecycle.

Built-in strategies are OFFSET, KEYSET (one sortable/filterable field plus Id, ASC/DESC), and native PAGE_CURSOR. A caller can subclass `DbPageStrategyFactory`, override `resolve`, and call:

```apex
DbQueryResult result = DbQueryService.execute(request, 100, new ApplicationPageStrategyFactory());
```

Call `super.resolve(name)` for built-in strategies. The factory is per call, not a mutable global registry. Custom strategy implementations must preserve user-mode access and bind safety; a trusted Apex extension is not a sandbox. Inputs are validated and the server page cap is applied before execution.

Tests are grouped by strategy, typed filters, schema access, security, extensions, and traversal beyond 2,000 offset rows. `QueryTestDataFactory` and `QueryTestSupport` have no dependency on the historical CRM app. The access-denial fixture uses the standard `Minimum Access - Salesforce` profile.

## HTTP

The HTTP module is independent of query and any business metadata. The client owns the service base endpoint and execution transport; each request owns the relative path and operation options. DTOs separate outbound raw results from public REST envelopes. ApiResponseFactory centralizes envelope construction; named ApiWriter helpers bind standard statuses and error codes. Builders validate full batches before callout side effects; services orchestrate ordered partial outcomes through an injected transport. REST readers/writers and exception mapping operate on explicit request/response objects. IApiBodyFormatter separates UTF-8 text representation from transport and HTTP policy; ApiJsonFormatter is the default and only built-in formatter. Applications explicitly supply additional formatters without changing the client or registering global state. No SOQL/DML occurs in the module. Callout batches respect remaining transaction callout slots; application-owned scheduling, persistence, idempotency and retry policies remain outside the toolkit. See [HTTP contracts](http-integration.md).

## Logging

Logging is an independent module with no application-module dependencies. Its Apex and trigger are deployable core source, but its `LogEvent__e` and `Log__c` schema is supplied by the consuming application. Developers refactor the concrete template for their event, object, and field names; see [the logger adaptation guide](logging.md).

The producer explicitly checks event create permission and publishes buffered entries on flush. The event subscriber owns a documented system-mode insert boundary. Publishers do not need stored-log access; readers receive a separate application-owned grant. Query and HTTP do not depend on logging.

## Trigger

Trigger is independent of query, HTTP, logging, and business metadata. It owns no objects or installed triggers. `AbstractTriggerHandler.run()` captures the active native context and dispatches one of seven protected callbacks. `TriggerContext` retains native list, map, and record references and rejects unavailable collections. Field comparisons support update events only. There is no database work, exception wrapping, retry policy, bypass registry, or recursion suppression. See [trigger contracts](trigger-toolkit.md) and the opt-in [Account example](../examples/trigger/README.md).

## Validation policy

Each feature needs behavior assertions, error cases, bulk tests where it processes collections, and tests for its real security boundary. Retain at least Salesforce's per-class 75% coverage requirement, targeting 90%+ on new logic. Coverage alone is not correctness: deep paging must verify exact population, no duplicate IDs, and termination.

Source checks and formatting run locally. Code Analyzer runs on core only, excluding upstream skill templates and archived snapshots by its workspace scope. CI fails on critical/high findings and publishes all findings for review. Apex validation must include the current local tests, not assume deployed test classes match the working tree.
