public with sharing class ReportRequest {
  @AuraEnabled
  public String objectName { get; set; }
  @AuraEnabled
  public List<String> fields { get; set; }
  @AuraEnabled
  public List<FilterCondition> filters { get; set; }
  @AuraEnabled
  public String orderBy { get; set; }
  @AuraEnabled
  public Boolean orderDesc { get; set; }
  @AuraEnabled
  public Integer limitSize { get; set; }
  public Integer offsetSize { get; set; }
}
