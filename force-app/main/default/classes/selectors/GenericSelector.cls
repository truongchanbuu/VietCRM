// Compatibility adapter for report callers. New database callers use DbQueryService.
public with sharing class GenericSelector {
  public static ReportResult execute(ReportRequest request, Integer maxRows) {
    if (request == null)
      throw new ConfigReportException('Report request is required');
    if (String.isBlank(request.objectName))
      throw new ConfigReportException('Object name is required');
    if (request.fields == null || request.fields.isEmpty())
      throw new ConfigReportException('At least one SELECT field is required');
    if (maxRows == null || maxRows <= 0)
      throw new ConfigReportException('maxRows must be positive');
    if (request.limitSize == null || request.limitSize <= 0)
      throw new ConfigReportException('limitSize must be positive');
    if (request.offsetSize != null && request.offsetSize > 2000)
      throw new ConfigReportException(
        'Offset exceeds the Salesforce maximum of 2000.'
      );
    DbQueryRequest query = new DbQueryRequest();
    query.objectName = request.objectName;
    query.fields = request.fields;
    query.filters = request.filters;
    query.orderBy = request.orderBy;
    query.orderDesc = request.orderDesc;
    query.pageSize = request.limitSize;
    query.page = new DbPageRequest();
    query.page.offsetSize = request.offsetSize;
    try {
      DbQueryResult page = DbQueryService.execute(query, maxRows);
      ReportResult result = new ReportResult();
      result.records = page.records;
      result.soql = page.soql;
      result.bindCount = page.bindCount;
      result.truncated = page.hasNext;
      return result;
    } catch (DbQueryException e) {
      throw new ConfigReportException(e.getMessage(), e);
    }
  }
}
