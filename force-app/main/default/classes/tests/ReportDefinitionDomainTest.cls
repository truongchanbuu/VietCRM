@IsTest
private class ReportDefinitionDomainTest {
  @IsTest
  static void aggregatesValidationErrorsWithoutDml() {
    Report_Definition__mdt invalidDefinition = new Report_Definition__mdt(
      DeveloperName = 'Invalid_Report',
      Object_Name__c = 'Account',
      Fields__c = 'Id, id',
      Is_Active__c = false,
      Default_Limit__c = 0
    );
    Integer queriesBefore = Limits.getQueries();
    List<String> errors = ReportDefinitionDomain.validate(invalidDefinition);
    System.assertEquals(
      3,
      errors.size(),
      'Inactive, duplicate field, and invalid limit are all reported.'
    );
    System.assertEquals(
      queriesBefore,
      Limits.getQueries(),
      'Domain validation stays in-memory.'
    );
  }
}
