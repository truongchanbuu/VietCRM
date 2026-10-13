public with sharing class CaseSelector {
  private static final List<String> BASE_FIELDS = new List<String>{
    'Id',
    'CaseNumber',
    'Subject',
    'Status',
    'Priority',
    'AccountId',
    'CreatedDate'
  };

  public static List<Case> getCasesPaged(Integer pageSize, Integer offsetSize) {
    DbQueryRequest request = new DbQueryRequest();
    request.objectName = 'Case';
    request.fields = BASE_FIELDS;
    request.filters = new List<FilterCondition>();
    request.orderBy = 'CreatedDate';
    request.orderDesc = true;
    request.pageSize = pageSize;
    request.page = new DbPageRequest();
    request.page.offsetSize = offsetSize;
    DbQueryResult result = DbQueryService.execute(
      request,
      pageSize == null || pageSize <= 0 ? 100 : pageSize
    );
    return (List<Case>) result.records;
  }
}
