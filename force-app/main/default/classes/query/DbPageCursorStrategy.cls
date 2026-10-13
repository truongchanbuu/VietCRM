public with sharing class DbPageCursorStrategy implements IDbPageStrategy {
  public DbQueryResult execute(
    DbQueryPlan plan,
    DbPageRequest page,
    Integer pageSize
  ) {
    if (
      page.afterId != null || (page.offsetSize != null && page.offsetSize != 0)
    )
      throw new DbQueryException(
        'PAGE_CURSOR does not accept offsetSize or afterId'
      );
    if (pageSize > 2000)
      throw new DbQueryException(
        'Pagination cursor page size cannot exceed 2000'
      );
    DbQueryService.requireRows(pageSize);
    String soql = plan.toSoql();
    try {
      Database.PaginationCursor cursor = Database.getPaginationCursorWithBinds(
        soql,
        plan.binds,
        AccessLevel.USER_MODE
      );
      DbQueryResult result = DbQueryService.fetchPage(
        cursor,
        0,
        pageSize,
        pageSize
      );
      result.soql = soql;
      result.bindCount = plan.binds.size();
      return result;
    } catch (DbQueryException e) {
      throw e;
    } catch (Exception e) {
      throw new DbQueryException(
        'Unable to open pagination cursor: ' + e.getMessage(),
        e
      );
    }
  }
}
