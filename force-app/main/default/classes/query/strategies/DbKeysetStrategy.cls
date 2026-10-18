public with sharing class DbKeysetStrategy implements IDbPageStrategy {
  // Currently only use Id for keyset
  public DbQueryResult execute(
    DbQueryPlan plan,
    DbPageRequest page,
    Integer pageSize
  ) {
    if (!plan.orderField.equalsIgnoreCase('Id')) {
      throw new DbQueryException('KEYSET currently requires orderBy Id');
    }
    if (page.offsetSize != null && page.offsetSize != 0) {
      throw new DbQueryException('KEYSET does not accept offsetSize');
    }

    Integer querySize = pageSize + 1;
    DbQueryService.requireRows(querySize);

    if (page.afterId != null) {
      plan.whereParts.add(
        'Id ' +
          (plan.descending ? '<' : '>') +
          ' ' +
          plan.bindValue(page.afterId)
      );
    }

    String soql = plan.toSoql() + ' LIMIT ' + plan.bindValue(querySize);
    DbQueryResult result = DbQueryService.queryPage(plan, soql, pageSize);
    result.strategy = DbPageRequest.KEYSET;
    if (result.hasNext) {
      result.nextAfterId = (Id) result.records[result.records.size() - 1]
        .get('Id');
    }

    return result;
  }
}
