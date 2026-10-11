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
    ReportRequest request = new ReportRequest();
    request.objectName = 'Case';
    request.fields = BASE_FIELDS;
    request.filters = new List<FilterCondition>();
    request.orderBy = 'CreatedDate';
    request.orderDesc = true;
    request.limitSize = pageSize;
    request.offsetSize = offsetSize;
    ReportResult result = GenericSelector.execute(
      request,
      pageSize == null || pageSize <= 0 ? 100 : pageSize
    );
    return (List<Case>) result.records;
  }
}
