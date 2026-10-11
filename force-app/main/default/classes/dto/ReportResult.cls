public with sharing class ReportResult {
  @AuraEnabled
  public List<SObject> records { get; set; }
  @AuraEnabled
  public String soql { get; set; }
  @AuraEnabled
  public Integer bindCount { get; set; }
  @AuraEnabled
  public Boolean truncated { get; set; }
  @AuraEnabled
  public String csv { get; set; }

  public ReportResult() {
    records = new List<SObject>();
    bindCount = 0;
    truncated = false;
  }
}
