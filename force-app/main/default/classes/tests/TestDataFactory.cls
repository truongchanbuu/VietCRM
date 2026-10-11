@IsTest
public with sharing class TestDataFactory {
  public static Account accountRecord(String tier) {
    return new Account(Name = 'ConfigReport Test Account', Tier__c = tier);
  }

  public static Case caseRecord(Id accountId, String subject) {
    return new Case(
      AccountId = accountId,
      Subject = subject,
      Status = 'New',
      Origin = 'Phone',
      Priority = 'High'
    );
  }

  public static Report_Definition__mdt definition(
    String name,
    String objectName,
    String fields,
    Integer limitSize
  ) {
    return new Report_Definition__mdt(
      DeveloperName = name,
      MasterLabel = name,
      Object_Name__c = objectName,
      Fields__c = fields,
      Default_Limit__c = limitSize,
      Is_Active__c = true,
      Post_Processor_Class__c = 'CsvExportProcessor'
    );
  }
}
