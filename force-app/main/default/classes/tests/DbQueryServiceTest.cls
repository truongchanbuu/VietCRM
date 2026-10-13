@IsTest
private class DbQueryServiceTest {
  @TestSetup
  static void setup() {
    insert new List<Account>{
      new Account(Name = 'Page A'),
      new Account(Name = 'Page B'),
      new Account(Name = 'Page C'),
      new Account(Name = 'Page D'),
      new Account(Name = 'Page E')
    };
  }
  private static DbQueryRequest request(String strategy) {
    DbQueryRequest r = new DbQueryRequest();
    r.objectName = 'Account';
    r.fields = new List<String>{ 'Id', 'Name' };
    r.filters = new List<FilterCondition>{
      new FilterCondition('Name', 'LIKE', 'Page %')
    };
    r.pageSize = 2;
    r.page = new DbPageRequest();
    r.page.strategy = strategy;
    return r;
  }
  @IsTest
  static void offsetPagesAndCap() {
    DbQueryRequest r = request('OFFSET');
    r.orderBy = 'Name';
    DbQueryResult first = DbQueryService.execute(r, 2);
    System.assertEquals(2, first.records.size());
    System.assertEquals(true, first.hasNext);
    System.assertEquals(2, first.nextOffset);
    System.assert(first.soql.contains('Name ASC, Id ASC'));
    r.page.offsetSize = first.nextOffset;
    DbQueryResult second = DbQueryService.execute(r, 2);
    System.assertEquals('Page C', second.records[0].get('Name'));
    r.page.offsetSize = second.nextOffset;
    DbQueryResult last = DbQueryService.execute(r, 2);
    System.assertEquals(1, last.records.size());
    System.assertEquals(false, last.hasNext);
    System.assertEquals(null, last.nextOffset);
    r.page.offsetSize = 0;
    System.assertEquals(1, DbQueryService.execute(r, 1).records.size());
    System.assertEquals(0, r.page.offsetSize, 'Request must not be mutated');
  }
  @IsTest
  static void keysetVisitsEachRecordInBothDirections() {
    for (Boolean descending : new List<Boolean>{ false, true }) {
      DbQueryRequest r = request('KEYSET');
      r.orderDesc = descending;
      Set<Id> ids = new Set<Id>();
      Boolean more = true;
      Integer pages = 0;
      while (more && pages < 4) {
        DbQueryResult result = DbQueryService.execute(r, 2);
        pages++;
        for (SObject record : result.records)
          System.assert(ids.add(record.Id), 'No duplicate across pages');
        more = result.hasNext;
        r.page.afterId = result.nextAfterId;
      }
      System.assertEquals(5, ids.size());
      System.assertEquals(3, pages);
      System.assertEquals(false, more);
    }
  }
  @IsTest
  static void nativeCursorResumesAndHandlesEnd() {
    DbQueryRequest r = request('PAGE_CURSOR');
    DbQueryResult first = DbQueryService.execute(r, 2);
    System.assertEquals(2, first.records.size());
    System.assertEquals(5, first.totalRecords);
    System.assertEquals(true, first.hasNext);
    System.assertEquals(2, first.nextPosition);
    DbQueryResult second = DbQueryService.fetchPage(
      first.cursor,
      first.nextPosition,
      2,
      2
    );
    System.assertEquals(2, second.records.size());
    System.assertNotEquals(first.records[0].Id, second.records[0].Id);
    DbQueryResult last = DbQueryService.fetchPage(
      second.cursor,
      second.nextPosition,
      2,
      2
    );
    System.assertEquals(1, last.records.size());
    System.assertEquals(false, last.hasNext);
    System.assertEquals(
      0,
      DbQueryService.fetchPage(first.cursor, 5, 2, 2).records.size()
    );
  }
  @IsTest
  static void locatorAndEmptyResults() {
    DbQueryRequest r = request('OFFSET');
    r.page = null;
    r.pageSize = null;
    Database.QueryLocatorIterator iterator = DbQueryService.queryLocator(r)
      .iterator();
    Integer count = 0;
    while (iterator.hasNext()) {
      iterator.next();
      count++;
    }
    System.assertEquals(5, count);
    for (
      String strategy : new List<String>{ 'OFFSET', 'KEYSET', 'PAGE_CURSOR' }
    ) {
      r = request(strategy);
      r.filters[0].value = 'No matching account';
      DbQueryResult result = DbQueryService.execute(r, 2);
      System.assertEquals(0, result.records.size());
      System.assertEquals(false, result.hasNext);
    }
  }
  @IsTest
  static void rejectsInvalidRequestsAndInjection() {
    DbQueryRequest r = request('OFFSET');
    r.page.offsetSize = -1;
    invalid(r);
    r.page.offsetSize = 2001;
    invalid(r);
    r = request('KEYSET');
    r.orderBy = 'Name';
    invalid(r);
    r = request('KEYSET');
    r.page.offsetSize = 1;
    invalid(r);
    r = request('PAGE_CURSOR');
    r.page.offsetSize = 1;
    invalid(r);
    r = request('PAGE_CURSOR');
    r.pageSize = 2001;
    try {
      DbQueryService.execute(r, 2001);
      System.assert(false);
    } catch (DbQueryException expected) {
      System.assert(expected.getMessage().contains('2000'));
    }
    r = request('UNKNOWN');
    invalid(r);
    r = request('OFFSET');
    r.fields = new List<String>{ 'Id FROM User' };
    invalid(r);
    r = request('OFFSET');
    r.pageSize = 0;
    invalid(r);
    invalid(null);
    r = request('KEYSET');
    r.filters[0].value = 'x\' OR Name != \'';
    DbQueryResult result = DbQueryService.execute(r, 2);
    System.assertEquals(0, result.records.size());
    System.assert(!result.soql.contains('OR Name'));
    try {
      DbQueryService.queryLocator(request('OFFSET'));
      System.assert(false);
    } catch (DbQueryException expected) {
      System.assert(expected.getMessage().contains('batch scope'));
    }
  }
  @IsTest
  static void exactPageAndBudget() {
    DbQueryRequest r = request('KEYSET');
    r.pageSize = 5;
    System.assertEquals(false, DbQueryService.execute(r, 5).hasNext);
    try {
      DbQueryService.requireRows(50001);
      System.assert(false);
    } catch (DbQueryException expected) {
      System.assert(expected.getMessage().contains('budget'));
    }
  }
  @IsTest
  static void typedFiltersRemainBoundAfterExtraction() {
    List<FilterCondition> filters = new List<FilterCondition>{
      new FilterCondition('Name', 'IN', new List<Object>{ 'Page A', 'Page B' }),
      new FilterCondition(
        'AnnualRevenue',
        'IN',
        new List<Object>{ '100', '200' }
      ),
      new FilterCondition(
        'LastActivityDate',
        'IN',
        new List<Object>{ '2026-01-01' }
      ),
      new FilterCondition(
        'CreatedDate',
        'IN',
        new List<Object>{ '2026-01-01 00:00:00' }
      ),
      new FilterCondition(
        'OwnerId',
        'IN',
        new List<Object>{ UserInfo.getUserId() }
      ),
      new FilterCondition('IsDeleted', 'IN', new List<Object>{ false }),
      new FilterCondition('AnnualRevenue', '>=', '100'),
      new FilterCondition('LastActivityDate', '=', '2026-01-01'),
      new FilterCondition('CreatedDate', '<', '2026-01-01 00:00:00'),
      new FilterCondition('IsDeleted', '=', 'false'),
      new FilterCondition('Name', '!=', null)
    };
    for (FilterCondition filter : filters) {
      DbQueryRequest r = request('OFFSET');
      r.filters = new List<FilterCondition>{ filter };
      DbQueryResult result = DbQueryService.execute(r, 2);
      System.assertEquals(2, result.bindCount, 'Filter and LIMIT are bound');
      System.assert(result.soql.contains(':b0'));
    }
    for (
      FilterCondition filter : new List<FilterCondition>{
        new FilterCondition('Name', 'LIKE', null),
        new FilterCondition('Name', 'IN', 'not a list'),
        new FilterCondition('Name', 'IN', new List<Object>()),
        new FilterCondition('IsDeleted', '=', 'maybe'),
        new FilterCondition('AnnualRevenue', '=', 'not a number'),
        new FilterCondition('Name', '>', 'Page A'),
        new FilterCondition('OwnerId', 'LIKE', '%'),
        new FilterCondition('Name', 'DELETE', 'Page A'),
        null
      }
    ) {
      DbQueryRequest r = request('OFFSET');
      r.filters = new List<FilterCondition>{ filter };
      invalid(r);
    }
    DbQueryRequest duplicate = request('OFFSET');
    duplicate.fields.add('name');
    invalid(duplicate);
  }

  @IsTest
  static void schemaValidationAndCaseAdapter() {
    System.assertEquals(0, CaseSelector.getCasesPaged(10, 0).size());
    List<Schema.SObjectType> types = SchemaHelper.getSObjectTypes(
      new List<String>{ ' Account ', 'Contact', 'account' }
    );
    System.assertEquals(3, types.size());
    System.assertEquals(types[0], types[2]);
    Set<String> accessible = SchemaHelper.getAccessibleFields('Account');
    accessible.clear();
    System.assert(SchemaHelper.getAccessibleFields('Account').contains('Name'));
    for (
      List<String> names : new List<List<String>>{
        null,
        new List<String>(),
        new List<String>{ '' },
        new List<String>{ 'NotAnObject' }
      }
    ) {
      try {
        SchemaHelper.getSObjectTypes(names);
        System.assert(false);
      } catch (DbQueryException expected) {
        System.assertNotEquals(null, expected.getMessage());
      }
    }
    for (
      String path : new List<String>{
        null,
        '',
        'Account.Owner.Manager.Name',
        'Missing',
        'Name.Name',
        'Account.Missing',
        'Account..Name'
      }
    ) {
      try {
        SchemaHelper.resolveFieldPath('Contact', path);
        System.assert(false, 'Invalid path: ' + path);
      } catch (DbQueryException expected) {
        System.assertNotEquals(null, expected.getMessage());
      }
    }
    System.assertEquals(
      'Account.Owner.Name',
      SchemaHelper.normalizeFieldPath('Contact', 'account.owner.name')
    );
    System.assertEquals(
      'Who.Name',
      SchemaHelper.normalizeFieldPath('Task', 'who.name')
    );
    System.assertEquals(true, SchemaHelper.isFilterable('Account', 'Name'));
  }

  @IsTest
  static void cursorDeletionAndExactPage() {
    DbQueryRequest r = request('PAGE_CURSOR');
    r.pageSize = 5;
    DbQueryResult all = DbQueryService.execute(r, 5);
    System.assertEquals(false, all.hasNext);
    System.assertEquals(null, all.nextPosition);
    r.pageSize = 2;
    DbQueryResult first = DbQueryService.execute(r, 2);
    List<Account> ordered = [SELECT Id FROM Account ORDER BY Id];
    delete ordered[2];
    DbQueryResult next = DbQueryService.fetchPage(
      first.cursor,
      first.nextPosition,
      2,
      2
    );
    System.assertEquals(2, next.records.size());
    System.assertEquals(false, next.hasNext);
    System.assertNotEquals(ordered[2].Id, next.records[0].Id);
    try {
      DbQueryService.fetchPage(first.cursor, 6, 2, 2);
      System.assert(false);
    } catch (DbQueryException expected) {
      System.assert(expected.getMessage().contains('position'));
    }
    try {
      DbQueryService.fetchPage(first.cursor, 0, 2001, 2001);
      System.assert(false);
    } catch (DbQueryException expected) {
      System.assert(expected.getMessage().contains('2000'));
    }
  }

  private static void invalid(DbQueryRequest r) {
    try {
      DbQueryService.execute(r, 10);
      System.assert(false, 'Expected DbQueryException');
    } catch (DbQueryException expected) {
      System.assertNotEquals(null, expected.getMessage());
    }
  }
}
