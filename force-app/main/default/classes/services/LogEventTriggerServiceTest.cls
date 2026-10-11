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

  @IsTest
  static void mixedBatchRetriesLockFailuresOnlyUpToCap() {
    List<Database.SaveResult> results = new List<Database.SaveResult>{
      (Database.SaveResult) JSON.deserialize(
        '{"success":true,"errors":[]}',
        Database.SaveResult.class
      ),
      failedResult('REQUIRED_FIELD_MISSING'),
      failedResult('UNABLE_TO_LOCK_ROW')
    };
    for (Integer retries = 0; retries <= 3; retries++) {
      Boolean retryRequested = false;
      try {
        LogEventTriggerService.handleResults(results, retries);
      } catch (EventBus.RetryableException expected) {
        retryRequested = true;
      }
      System.assertEquals(
        retries < 3,
        retryRequested,
        'Initial attempt plus at most three retries'
      );
    }
    System.assertEquals(
      0,
      Limits.getDmlStatements(),
      'Salesforce redelivers; no inline insert loop'
    );
  }

  @IsTest
  static void permanentErrorsDoNotRequestRetry() {
    Boolean retryRequested = false;
    try {
      LogEventTriggerService.handleResults(
        new List<Database.SaveResult>{
          failedResult('REQUIRED_FIELD_MISSING'),
          failedResult('STRING_TOO_LONG')
        },
        0
      );
    } catch (EventBus.RetryableException unexpected) {
      retryRequested = true;
    }
    System.assertEquals(
      false,
      retryRequested,
      'Retrying unchanged invalid data cannot help'
    );
    System.assertEquals(0, Limits.getDmlStatements());
  }

  private static Database.SaveResult failedResult(String code) {
    return (Database.SaveResult) JSON.deserialize(
      '{"success":false,"errors":[{"statusCode":"' +
        code +
        '","message":"Simulated failure","fields":[]}]}',
      Database.SaveResult.class
    );
  }
}
