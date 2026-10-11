@IsTest
private class CaseServiceTest {
  @IsTest
  static void escalatesTwoHundredCasesWithOneReportQuery() {
    Account account = TestDataFactory.accountRecord('VIP');
    insert account;
    List<Case> casesToInsert = new List<Case>();
    for (Integer i = 0; i < 200; i++)
      casesToInsert.add(
        TestDataFactory.caseRecord(account.Id, 'Bulk Case ' + i)
      );
    insert casesToInsert;

    CaseFeatureFlags.overrides.put('configreport', true);
    ConfigReportService.definitionOverrides.put(
      'open_cases',
      TestDataFactory.definition(
        'Open_Cases',
        'Case',
        'Id,CaseNumber,Subject,Status,AccountId,CreatedDate',
        200
      )
    );
    CaseService.reportQueryCount = 0;
    CaseService.eventPublishCount = 0;

    Integer queriesBefore = Limits.getQueries();
    for (Case record : casesToInsert)
      record.Status = 'Escalated';
    update casesToInsert;
    Integer queriesUsed = Limits.getQueries() - queriesBefore;

    System.assertEquals(
      1,
      CaseService.reportQueryCount,
      'Bulk escalation runs one report query for all Accounts.'
    );
    System.assertEquals(
      200,
      CaseService.eventPublishCount,
      'One platform event is prepared per escalated Case.'
    );
    System.assert(
      queriesUsed <= 2,
      'Query count stays constant for 200 records: ' + queriesUsed
    );
  }
}
