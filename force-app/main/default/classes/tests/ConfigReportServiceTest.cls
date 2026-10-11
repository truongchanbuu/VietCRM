@IsTest
private class ConfigReportServiceTest {
  @IsTest
  static void runsConfiguredDefinitionAndProducesCsv() {
    System.assert(
      CaseFeatureFlags.isEnabled('ConfigReport'),
      'This integration test requires ConfigReport enabled in CMDT.'
    );
    Account account = TestDataFactory.accountRecord('VIP');
    insert account;
    Case caseRecord = TestDataFactory.caseRecord(
      account.Id,
      'Service report row'
    );
    insert caseRecord;
    ReportResult result = ConfigReportService.run(
      'Open_Cases',
      new List<FilterCondition>{ new FilterCondition('Id', '=', caseRecord.Id) }
    );
    System.assertEquals(1, result.records.size());
    System.assertEquals(caseRecord.Id, result.records[0].get('Id'));
    System.assert(result.csv.contains('Service report row'));
    System.assert(result.soql.contains(':b0'));
  }

  @IsTest
  static void lwcBoundaryHidesInternalDetails() {
    try {
      ConfigReportService.runForLwc(
        'Missing_Report_For_Test',
        new List<FilterCondition>()
      );
      System.assert(false, 'LWC must receive a handled error.');
    } catch (AuraHandledException expected) {
      System.assert(!expected.getMessage().contains('SELECT'));
      System.assert(!expected.getMessage().contains('Missing_Report_For_Test'));
    }
  }

  @IsTest
  static void unknownFlagDefaultsToDisabled() {
    System.assertEquals(
      false,
      CaseFeatureFlags.isEnabled('Missing_Flag_For_Test')
    );
    System.assertEquals(false, CaseFeatureFlags.isEnabled(null));
  }
}
