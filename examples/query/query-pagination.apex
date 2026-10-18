// Read-only example. Run: sf apex run --file examples/apex/query-pagination.apex --target-org dev
DbQueryRequest request = new DbQueryRequest();
request.objectName = 'Account';
request.fields = new List<String>{ 'Id', 'Name' };
request.pageSize = 20;
request.page = new DbPageRequest();
request.page.strategy = DbPageRequest.KEYSET;
request.orderBy = 'Name';
DbQueryResult first = DbQueryService.execute(request, 50);
if (first.hasNext) {
  request.page.afterId = first.nextAfterId;
  request.page.afterValue = first.nextAfterValue;
  DbQueryResult second = DbQueryService.execute(request, 50);
  Assert.areNotEqual(
    first.records[0].Id,
    second.records[0].Id,
    'Pages advance'
  );
}
