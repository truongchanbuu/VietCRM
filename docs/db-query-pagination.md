# DB query contracts and pagination

`DbQueryRequest`, `DbQueryResult`, and `DbQueryException` belong to the database layer. CSV and PII masking remain report concerns. The old report adapters and Case selectors are preserved on `feature/developer-kit-foundation` and are excluded from this query-only branch.

`DbQueryCompiler` validates object/field paths, operators, and filter values. All executors use bind variables and explicit `AccessLevel.USER_MODE`. Pagination values are not interpolated into SOQL. Queries always have deterministic ordering: `Id` by default, or the requested field followed by `Id` as a tie breaker.

## Strategies

| Entry point                   | Use                                       | Continuation                                       | Limits / behavior                                                                                                                                       |
| ----------------------------- | ----------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `execute`, `OFFSET` (default) | Small lists, direct page selection        | `nextOffset`                                       | Offset 0–2000. `hasNext` reports additional records; `nextOffset` is null if the next offset exceeds 2000. Switch strategy by starting a new query.     |
| `execute`, `KEYSET`           | Sequential traversal beyond OFFSET limits | `nextAfterId` + `nextAfterValue`                   | Supports one sortable/filterable field plus `Id`, ASC/DESC. Picklist order is rejected. No snapshot isolation; inserts/deletes can affect later pages.  |
| `execute`, `PAGE_CURSOR`      | Native Salesforce pagination cursor       | `cursor` and `nextPosition`, passed to `fetchPage` | Opens the whole matching result set, without a page-sized SOQL LIMIT. Maximum 2,000 records per page and 100,000 per cursor; native expiration applies. |
| `queryLocator`                | `Database.Batchable.start()`              | Salesforce manages batch chunks                    | Returns `Database.QueryLocator`; not a UI token. Rejects `page` and `pageSize`; use batch scope to control chunk size.                                  |

`maxRows` is a server-supplied **per-page** cap, not a total-result cap. Do not take this cap from an untrusted client. OFFSET and KEYSET fetch one extra record to establish `hasNext`. Insufficient row budget raises an exception instead of silently reporting the end of the results. OFFSET also reserves budget for skipped rows. Maximum effective page size is 49,999 for OFFSET/KEYSET and 2,000 for PAGE_CURSOR; choose a much smaller cap for UI/heap limits.

```apex
DbQueryRequest request = new DbQueryRequest();
request.objectName = 'Account';
request.fields = new List<String>{ 'Id', 'Name' };
request.pageSize = 50;
request.page = new DbPageRequest();
request.page.strategy = 'KEYSET';
DbQueryResult first = DbQueryService.execute(request, 100);
if (first.hasNext) {
    request.page.afterId = first.nextAfterId;
    DbQueryResult second = DbQueryService.execute(request, 100);
}
```

### Keyset by another field

Set `orderBy` to a field API name or parent field path, for example `Name`, `AnnualRevenue`, `CreatedDate`, or `Account.Name`. The compiler includes the sort field and `Id` in the projection when KEYSET is selected. Results use `(orderBy, Id)` in the requested direction. Common text, numeric/currency, date/datetime, reference, and checkbox fields are supported. Checkbox continuation uses equality groups rather than `<`/`>`.

```apex
request.orderBy = 'Name';
request.page = new DbPageRequest();
request.page.strategy = DbPageRequest.KEYSET;
DbQueryResult firstByName = DbQueryService.execute(request, 100);
if (firstByName.hasNext) {
    request.page.afterId = firstByName.nextAfterId;
    request.page.afterValue = firstByName.nextAfterValue;
    DbQueryResult secondByName = DbQueryService.execute(request, 100);
}
```

Pass **both** continuation properties unchanged, including a null `nextAfterValue`. `afterId` determines whether this is a continuation; null `afterValue` is a real null field boundary, not an instruction to look up the anchor. Id-only ordering still uses `afterId` alone. Returning boundary values avoids an extra query and continues when the anchor record is deleted. Date/datetime and numeric values from JSON are coerced back to their field types.

The strategy follows Salesforce's native null ordering, preserving `Id` order within the null group. Scalar and parent scalar fields put nulls first; direct reference fields put nulls last when descending. It rejects unsortable fields in the compiler, then non-filterable fields and picklists before executing a keyset query. Salesforce has no generic describe flag for comparison semantics. Picklist order depends on configured rank and cannot be represented by a normal scalar seek predicate; use OFFSET/PAGE_CURSOR or an application-maintained sortable scalar rank instead.

Validation deliberately does not enforce indexes, uniqueness, immutability, field naming, or application-specific field policies. The calling developer owns query selectivity, supported locale/collation behavior, currency normalization in multi-currency orgs, and keeping the request and boundary together. Other platform-specific query limitations surface as `DbQueryException` with the original error. This is one chosen sort field plus an Id tie-breaker, not arbitrary multi-column ordering or a signed cursor token.

Keep the same filters, ordering, and object across keyset pages. `afterId` is a boundary value, not an authorization token. Each page is queried in user mode.

```apex
request.page = new DbPageRequest();
request.page.strategy = 'PAGE_CURSOR';
DbQueryResult first = DbQueryService.execute(request, 100);
if (first.hasNext) {
    DbQueryResult second = DbQueryService.fetchPage(
        first.cursor, first.nextPosition, request.pageSize, 100
    );
}
```

Cursor continuation accepts the native cursor separately, so it cannot silently ignore a changed query request. To change filters or ordering, open a new cursor. Keep cursor handles scoped to the user who created them; restart when the platform reports expiration. The module does not expose an Aura controller.

```apex
// Inside Database.Batchable.start():
DbQueryRequest request = new DbQueryRequest();
request.objectName = 'Account';
request.fields = new List<String>{ 'Id', 'Name' };
return DbQueryService.queryLocator(request);
```

To add another page strategy, implement `IDbPageStrategy`, subclass `DbPageStrategyFactory`, and pass that factory to the three-argument `DbQueryService.execute` overload. The compiler and service entry points do not change. QueryLocator stays separate because its lifecycle and result type differ from a fetched page.

## Migration and validation

The core API is `DbQueryService`. Report-specific DTOs, processors, and the legacy adapter are preserved on the foundation branch; applications using them must migrate deliberately. Negative offsets fail validation. Queries without explicit ordering sort by Id. Insufficient row budget raises an explicit error.

Run `npm run validate:core -- --target-org dev` to compile all current core source and execute its local test classes in a check-only deployment. Tests cover strategy boundaries, cursor deletion handling, typed filters, schema access, denied object access, and traversal across 2,501 records.

## Platform references

- [Salesforce cursor release notes](https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_cursors.htm&release=260&type=5)
- [PaginationCursor reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_PaginationCursor.htm)
- [Database reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database.htm)
