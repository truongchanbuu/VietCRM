public with sharing class DbKeysetStrategy implements IDbPageStrategy {
  // Unique, non-null Id ordering avoids ambiguous boundaries and duplicate rows.
  public DbQueryResult execute(
    DbQueryPlan plan,
    DbPageRequest page,
    Integer pageSize
  ) {
    if (!plan.orderField.equalsIgnoreCase('Id'))
      throw new DbQueryException('KEYSET currently requires orderBy Id');
    if (page.offsetSize != null && page.offsetSize != 0)
      throw new DbQueryException('KEYSET does not accept offsetSize');
    DbQueryService.requireRows(pageSize + 1);
    if (page.afterId != null)
      plan.whereParts.add(
        'Id ' +
          (plan.descending ? '<' : '>') +
          ' ' +
          plan.bindValue(page.afterId)
      );
    String soql = plan.toSoql() + ' LIMIT ' + plan.bindValue(pageSize + 1);
    DbQueryResult result = DbQueryService.queryPage(plan, soql, pageSize);
    result.strategy = 'KEYSET';
    if (result.hasNext)
      result.nextAfterId = (Id) result.records[result.records.size() - 1]
        .get('Id');
    return result;
  }
}
