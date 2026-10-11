@IsTest
private class ConfigReportServiceTest {
  @IsTest
  static void disabledFeatureStopsBeforeQuery() {
    CaseFeatureFlags.overrides.put('configreport', false);
    Integer beforeQueries = Limits.getQueries();
    try {
      ConfigReportService.run('does-not-matter', new List<FilterCondition>());
      System.assert(false, 'Disabled feature must reject the request.');
    } catch (ConfigReportException expected) {
      System.assertEquals('Feature disabled', expected.getMessage());
    }
    System.assertEquals(
      beforeQueries,
      Limits.getQueries(),
      'Feature gate is evaluated before data access.'
    );
  }

  @IsTest
  static void runsInjectedDefinitionAndProducesCsv() {
    Account account = TestDataFactory.accountRecord('VIP');
    insert account;
    Case caseRecord = TestDataFactory.caseRecord(
      account.Id,
      'Service report row'
    );
    insert caseRecord;
    CaseFeatureFlags.overrides.put('configreport', true);
    ConfigReportService.definitionOverrides.put(
      'test_open',
      TestDataFactory.definition(
        'test_open',
        'Case',
        'Id,Subject,AccountId',
        50
      )
    );
    ReportResult result = ConfigReportService.run(
      'test_open',
      new List<FilterCondition>{ new FilterCondition('Id', '=', caseRecord.Id) }
    );
    System.assertEquals(1, result.records.size());
    System.assert(
      result.csv.startsWith('Id,Subject,AccountId\r\n'),
      'Processor emits configured headers in order.'
    );
    System.assert(
      result.soql.contains(':b0'),
      'Filter is represented as a bind placeholder.'
    );
  }

  @IsTest
  static void processorNameAndInterfaceFailuresAreClear() {
    ReportResult emptyResult = new ReportResult();
    assertProcessorError(
      'NoSuchProcessorForTest',
      'was not found',
      emptyResult
    );
    assertProcessorError(
      'CaseSelector',
      'implement IReportPostProcessor',
      emptyResult
    );
  }

  @IsTest
  static void lwcBoundaryHidesInternalDetails() {
    CaseFeatureFlags.overrides.put('configreport', false);
    try {
      ConfigReportService.runForLwc(
        'secret-soql-is-not-client-data',
        new List<FilterCondition>()
      );
      System.assert(false, 'LWC receives a handled error.');
    } catch (AuraHandledException expected) {
      System.assert(!expected.getMessage().contains('SELECT'));
      System.assert(!expected.getMessage().contains('secret-soql'));
    }
  }

  @IsTest
  static void missingHierarchySettingFallsBackToOneHundred() {
    System.assertEquals(
      100,
      ConfigReportService.getMaxRows(),
      'No hierarchy record uses documented fallback.'
    );
  }

  @IsTest
  static void orgHierarchySettingIsUsed() {
    insert new ReportConfig__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      MaxRows__c = 200
    );
    System.assertEquals(
      200,
      ConfigReportService.getMaxRows(),
      'Org setting is used when user/profile values are absent.'
    );
  }

  @IsTest
  static void profileSettingOverridesOrg() {
    insert new ReportConfig__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      MaxRows__c = 200
    );
    Profile currentProfile = [
      SELECT Id
      FROM Profile
      WHERE Id = :UserInfo.getProfileId()
    ];
    insert new ReportConfig__c(
      SetupOwnerId = currentProfile.Id,
      MaxRows__c = 1000
    );
    System.assertEquals(
      1000,
      ConfigReportService.getMaxRows(),
      'Profile value overrides org default.'
    );
  }

  @IsTest
  static void userSettingOverridesProfile() {
    insert new ReportConfig__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      MaxRows__c = 200
    );
    Profile currentProfile = [
      SELECT Id
      FROM Profile
      WHERE Id = :UserInfo.getProfileId()
    ];
    insert new ReportConfig__c(
      SetupOwnerId = currentProfile.Id,
      MaxRows__c = 1000
    );
    insert new ReportConfig__c(
      SetupOwnerId = UserInfo.getUserId(),
      MaxRows__c = 2000
    );
    System.assertEquals(
      2000,
      ConfigReportService.getMaxRows(),
      'User value overrides profile default.'
    );
  }

  private static void assertProcessorError(
    String processorName,
    String expectedText,
    ReportResult result
  ) {
    try {
      ConfigReportService.invokeProcessor(
        processorName,
        result,
        new List<String>{ 'Id' },
        'test'
      );
      System.assert(false, 'Invalid processor must fail: ' + processorName);
    } catch (ConfigReportException expected) {
      System.assert(
        expected.getMessage().contains(expectedText),
        expected.getMessage()
      );
    }
  }
}
