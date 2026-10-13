public with sharing class DbQueryService {
  public static DbQueryResult execute(DbQueryRequest request, Integer maxRows) {
    if (request == null)
      throw new DbQueryException('Query request is required');
    Integer size = effectiveSize(request.pageSize, maxRows);
    DbPageRequest page = request.page == null
      ? new DbPageRequest()
      : request.page;
    String strategy = String.isBlank(page.strategy)
      ? 'OFFSET'
      : page.strategy.trim().toUpperCase();
    IDbPageStrategy implementation;
    if (strategy == 'OFFSET')
      implementation = new DbOffsetStrategy();
    else if (strategy == 'KEYSET')
      implementation = new DbKeysetStrategy();
    else if (strategy == 'PAGE_CURSOR')
      implementation = new DbPageCursorStrategy();
    else
      throw new DbQueryException(
        'Unsupported page strategy: ' +
          strategy +
          '. Use queryLocator() for Batch Apex.'
      );
    return implementation.execute(DbQueryCompiler.compile(request), page, size);
  }

  // Intended for Database.Batchable.start(). The batch scope controls chunk size.
  public static Database.QueryLocator queryLocator(DbQueryRequest request) {
    if (request != null && (request.page != null || request.pageSize != null))
      throw new DbQueryException(
        'QueryLocator uses batch scope, not page or pageSize'
      );
    DbQueryPlan plan = DbQueryCompiler.compile(request);
    try {
      return Database.getQueryLocatorWithBinds(
        plan.toSoql(),
        plan.binds,
        AccessLevel.USER_MODE
      );
    } catch (Exception e) {
      throw new DbQueryException(
        'Unable to open query locator: ' + e.getMessage(),
        e
      );
    }
  }

  // Resume the native cursor returned by PAGE_CURSOR. Position is zero-based.
  public static DbQueryResult fetchPage(
    Database.PaginationCursor cursor,
    Integer position,
    Integer pageSize,
    Integer maxRows
  ) {
    Integer size = effectiveSize(pageSize, maxRows);
    if (cursor == null || position == null || position < 0)
      throw new DbQueryException(
        'Cursor and non-negative position are required'
      );
    if (size > 2000)
      throw new DbQueryException(
        'Pagination cursor page size cannot exceed 2000'
      );
    try {
      DbQueryResult result = new DbQueryResult();
      result.strategy = 'PAGE_CURSOR';
      result.cursor = cursor;
      result.totalRecords = cursor.getNumRecords();
      if (position > result.totalRecords)
        throw new DbQueryException('Cursor position exceeds result size');
      if (position == result.totalRecords)
        return result;
      Integer fetchSize = Math.min(size, result.totalRecords - position);
      requireRows(fetchSize);
      Database.CursorFetchResult fetched = cursor.fetchPage(
        position,
        fetchSize
      );
      result.records = fetched.getRecords();
      // isDone() describes completion of this fetch, not exhaustion of the cursor.
      Integer consumed =
        position +
        result.records.size() +
        fetched.getNumDeletedRecords();
      result.hasNext = consumed < result.totalRecords;
      if (result.hasNext) {
        Integer nextIndex = fetched.getNextIndex();
        result.nextPosition = nextIndex > position ? nextIndex : consumed;
        if (result.nextPosition <= position)
          throw new DbQueryException(
            'Pagination cursor made no progress; restart the query'
          );
      }
      return result;
    } catch (DbQueryException e) {
      throw e;
    } catch (Exception e) {
      throw new DbQueryException(
        'Unable to fetch cursor page; restart the query if expired: ' +
        e.getMessage(),
        e
      );
    }
  }

  public static Integer effectiveSize(Integer pageSize, Integer maxRows) {
    if (pageSize == null || pageSize <= 0 || maxRows == null || maxRows <= 0)
      throw new DbQueryException('pageSize and maxRows must be positive');
    Integer size = Math.min(pageSize, maxRows);
    if (size > 49999)
      throw new DbQueryException('Page size cannot exceed 49999');
    return size;
  }
  public static void requireRows(Integer count) {
    if (Limits.getLimitQueryRows() - Limits.getQueryRows() < count)
      throw new DbQueryException(
        'Insufficient query-row budget for requested page'
      );
  }
  public static DbQueryResult queryPage(
    DbQueryPlan plan,
    String soql,
    Integer pageSize
  ) {
    try {
      DbQueryResult result = new DbQueryResult();
      result.records = Database.queryWithBinds(
        soql,
        plan.binds,
        AccessLevel.USER_MODE
      );
      result.hasNext = result.records.size() > pageSize;
      if (result.hasNext)
        result.records.remove(result.records.size() - 1);
      result.soql = soql;
      result.bindCount = plan.binds.size();
      return result;
    } catch (Exception e) {
      throw new DbQueryException(
        'User-mode query failed: ' + e.getMessage(),
        e
      );
    }
  }
}
