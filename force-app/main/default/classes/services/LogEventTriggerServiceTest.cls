@IsTest
private class LogEventTriggerServiceTest {
  @IsTest
  static void emptyBatchDoesNoWork() {
    Integer beforeDml = Limits.getDmlStatements();
    LogEventTriggerService.save(new List<LogEvent__e>());
    System.assertEquals(beforeDml, Limits.getDmlStatements());
  }

  @IsTest
  static void bulkPartialInsertKeepsValidLogs() {
    List<LogEvent__e> events = new List<LogEvent__e>();
    Set<String> expectedMessages = new Set<String>();
    for (Integer i = 0; i < 200; i++) {
      Boolean valid = Math.mod(i, 2) != 0;
      events.add(
        new LogEvent__e(
          Level__c = 'INFO',
          Message__c = 'Log ' + i,
          TransactionId__c = valid ? Request.getCurrent().getRequestId() : null
        )
      );
      if (valid) {
        expectedMessages.add('Log ' + i);
      }
    }
    Test.startTest();
    LogEventTriggerService.save(events);
    System.assertEquals(1, Limits.getDmlStatements(), 'One bulk insert only');
    Test.stopTest();
    List<Log__c> logs = [SELECT Message__c FROM Log__c WITH SYSTEM_MODE];
    Set<String> actualMessages = new Set<String>();
    for (Log__c logRecord : logs) {
      actualMessages.add(logRecord.Message__c);
    }
    System.assertEquals(100, logs.size());
    System.assertEquals(
      expectedMessages,
      actualMessages,
      'Valid rows survive permanent failures'
    );
  }
}
