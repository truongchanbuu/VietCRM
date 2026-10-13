public with sharing class DbOffsetStrategy implements IDbPageStrategy {
  public DbQueryResult execute(
    DbQueryPlan plan,
    DbPageRequest page,
    Integer pageSize
  ) {
    Integer offsetSize = page.offsetSize == null ? 0 : page.offsetSize;
    if (offsetSize < 0 || offsetSize > 2000)
      throw new DbQueryException('Offset must be between 0 and 2000');
    if (page.afterId != null)
      throw new DbQueryException('OFFSET does not accept afterId');
    DbQueryService.requireRows(pageSize + 1 + offsetSize);
    String soql = plan.toSoql() + ' LIMIT ' + plan.bindValue(pageSize + 1);
    if (offsetSize > 0)
      soql += ' OFFSET ' + plan.bindValue(offsetSize);
    DbQueryResult result = DbQueryService.queryPage(plan, soql, pageSize);
    result.strategy = 'OFFSET';
    if (result.hasNext && offsetSize + pageSize <= 2000)
      result.nextOffset = offsetSize + pageSize;
    return result;
  }
}
