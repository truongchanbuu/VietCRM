public with sharing class DbPageRequest {
  // OFFSET (default), KEYSET, or PAGE_CURSOR. QueryLocator has a separate API.
  @AuraEnabled
  public String strategy { get; set; }
  @AuraEnabled
  public Integer offsetSize { get; set; }
  @AuraEnabled
  public Id afterId { get; set; }
}
