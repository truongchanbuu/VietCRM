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

    System.assert(
      CaseFeatureFlags.isEnabled('ConfigReport'),
      'This integration test requires the ConfigReport flag enabled in CMDT.'
    );

    Integer queriesBefore = Limits.getQueries();
    for (Case record : casesToInsert)
      record.Status = 'Escalated';
    update casesToInsert;
    Integer queriesUsed = Limits.getQueries() - queriesBefore;

    System.assertEquals(
      1,
      queriesUsed,
      'Bulk escalation runs one report query for all Accounts.'
    );
  }
}
