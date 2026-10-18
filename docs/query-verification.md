# Query module verification

Validated on 2026-10-18 against development org alias `dev`, using local query production classes and tests together.

- `npm test`: passed; one module, 27 Apex classes/interfaces, formatting passed.
- `npm run analyze:core`: passed the severity 1/2 gate; 0 critical, 0 high, 60 moderate, and 123 low findings. Remaining findings include API documentation, complexity, test runAs policy, and naming. This is not a zero-findings result.
- `npm run validate:core -- --target-org dev`: succeeded, job `0Afbm00000k0pT4CAI`; 27 metadata components, 48 tests passed, 0 failures, 0 coverage warnings. Check-only: no metadata persisted.
- Aggregate executable-line coverage for the returned query classes: 661/722 (91.55%). Every production class with executable lines exceeds the Salesforce 75% minimum.

## Exercised behavior

Tests cover OFFSET boundaries, keyset ascending/descending continuation, traversal of 2,501 records without duplicates, native pagination cursor continuation and deletion behavior, QueryLocator, typed filters, bound injection-like values, relationship/schema validation, denied object read access, row budgets, invalid pagination inputs, and an injected custom strategy factory.

## Scope and limitations

Deployable source contains only `classes/query/<role>`, with no custom-object, logging, feature-flag, Case, or reporting dependency. Broader foundation work and historical CRM source remain recoverable at `feature/developer-kit-foundation` commit `aee1a4d`.

Validation used an existing development org, not a fresh scratch org. KEYSET supports one sortable/filterable field plus Id, and rejects picklist order. Native cursors retain platform lifecycle limits. Installed skills and local MCP configuration are development tooling; MCP connectivity is not part of this feature verification. Removing files from Git does not delete existing org components.

## Composite keyset update

Feature branch: `feature/query-composite-keyset`. Keyset strategy coverage is 76/78 executable lines (97.44%). New integration tests compare exact platform ordering over 251 records in both directions for text, phone, email, integer, currency, date, datetime, checkbox, reference, and parent scalar fields. They span duplicate/null groups, exercise JSON continuation values, and verify deletion of an anchor record, bound injection-like values, early rejection, and integer IN filter binds.

The compiler projects the sort field and Id when necessary. Non-Id continuation uses both `afterId` and `afterValue`; a null value is preserved. Lookup-Id nulls trail descending order; scalar nulls precede values. Validation does not impose index, uniqueness, or immutability policies. Locale/collation, multi-currency suitability, query selectivity, and consistency of requests between calls remain caller responsibilities.

Remaining PMD findings include helper-based assertion detection and runAs recommendations in general behavior tests, in addition to inherited documentation/complexity findings. The dedicated access-denial test still uses runAs; the strategy always executes user-mode queries. No findings were hidden by severity overrides or suppression annotations.
