# DB query contracts and pagination

`DbQueryRequest`, `DbQueryResult`, and `DbQueryException` belong to the database layer. CSV and PII masking remain report concerns. `GenericSelector.execute(ReportRequest, maxRows)` is a compatibility adapter; it translates query errors back to `ConfigReportException`. `CaseSelector` now uses the database contract directly.

`DbQueryCompiler` validates object/field paths, operators, and filter values. All executors use bind variables and explicit `AccessLevel.USER_MODE`. Pagination values are not interpolated into SOQL. Queries always have deterministic ordering: `Id` by default, or the requested field followed by `Id` as a tie breaker.

## Strategies

| Entry point                   | Use                                       | Continuation                                       | Limits / behavior                                                                                                                                       |
| ----------------------------- | ----------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `execute`, `OFFSET` (default) | Small lists, direct page selection        | `nextOffset`                                       | Offset 0–2000. `hasNext` reports additional records; `nextOffset` is null if the next offset exceeds 2000. Switch strategy by starting a new query.     |
| `execute`, `KEYSET`           | Sequential traversal beyond OFFSET limits | `nextAfterId`                                      | Currently supports `Id ASC/DESC` only. Other sort fields are rejected. No snapshot isolation; inserts/deletes can affect later pages.                   |
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

Cursor continuation accepts the native cursor separately, so it cannot silently ignore a changed query request. To change filters or ordering, open a new cursor. Keep cursor handles scoped to the user who created them; restart when the platform reports expiration. This change does not expose a new unrestricted Aura controller or alter the existing report endpoint.

```apex
// Inside Database.Batchable.start():
DbQueryRequest request = new DbQueryRequest();
request.objectName = 'Account';
request.fields = new List<String>{ 'Id', 'Name' };
return DbQueryService.queryLocator(request);
```

To add another page strategy, implement `IDbPageStrategy` and register it in `DbQueryService.execute`. The compiler and report adapter do not change. QueryLocator stays separate because its lifecycle and result type differ from a fetched page.

## Compatibility

Existing report request/result properties and post-processors remain available. Negative offsets now raise a validation error. Queries without explicit ordering now sort by Id. Low row budget now fails explicitly instead of returning an incomplete page with misleading `truncated=false`.

## Platform references

- [Salesforce cursor release notes](https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_cursors.htm&release=260&type=5)
- [PaginationCursor reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_PaginationCursor.htm)
- [Database reference (queryWithBinds and getQueryLocatorWithBinds)](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database.htm)

## Validation scope

The dry-run package contains `classes/query`, `classes/selectors`, and the new `DbQueryServiceTest` class. It runs that test together with the existing `GenericSelectorTest`, `ConfigReportServiceTest`, and `PiiMaskProcessorTest` classes on the `dev` org. The three existing test classes are taken from the org, not uploaded from the working tree. This validates the query change and compatibility with the deployed report contract; it is not a full validation of other in-progress local changes. No metadata is persisted by this check-only deployment.

```sh
sf project deploy start --dry-run --target-org dev \
  --source-dir force-app/main/default/classes/query \
  --source-dir force-app/main/default/classes/selectors \
  --source-dir force-app/main/default/classes/tests/DbQueryServiceTest.cls \
  --test-level RunSpecifiedTests \
  --tests DbQueryServiceTest --tests GenericSelectorTest \
  --tests ConfigReportServiceTest --tests PiiMaskProcessorTest
```
