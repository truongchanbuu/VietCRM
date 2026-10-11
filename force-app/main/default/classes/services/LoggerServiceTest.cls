@IsTest
private class LoggerServiceTest {
  @IsTest
  static void mappedEventCanBeSaved() {
    LogEvent__e eventRecord = new LogEvent__e(
      Level__c = 'INFO',
      Message__c = 'Mapping diagnostic',
      Source__c = 'LoggerServiceTest',
      TransactionId__c = Request.getCurrent().getRequestId(),
      UserId__c = UserInfo.getUserId(),
      OccurredAt__c = System.now(),
      Operation__c = 'UNIT_TEST',
      Status__c = 'New'
    );
    Log__c mappedLog = LogEventTriggerService.fromEvent(eventRecord);
    LogEvent__e initializedEvent = (LogEvent__e) LogEvent__e.SObjectType.newSObject(null, true);
    mappedLog.EventUuid__c = initializedEvent.EventUuid;
    System.assertNotEquals(null, mappedLog.EventUuid__c);
    Database.SaveResult result = Database.insert(mappedLog, false);
    System.assert(result.isSuccess(), JSON.serialize(result.getErrors()));
  }

  @IsTest
  static void flushPublishesInfoAndErrorEvents() {
    String marker = 'logger-test-' + String.valueOf(DateTime.now().getTime());
    LoggerService logger = LoggerService.fromSource('LoggerServiceTest');
    Exception capturedException;
    try {
      Integer invalidResult = 1 / 0;
    } catch (Exception exceptionValue) {
      capturedException = exceptionValue;
    }

    Test.startTest();
    logger.info(marker + '-info', 'UNIT_TEST', UserInfo.getUserId(), null);
    logger.error(marker + '-error', 'UNIT_TEST', UserInfo.getUserId(), capturedException);
    LoggerService.flush();
    Test.getEventBus().deliver();
    Test.stopTest();

    List<Log__c> logs = [
      SELECT
        Level__c,
        Message__c,
        Source__c,
        ExceptionType__c,
        StackTrace__c,
        TransactionId__c,
        UserId__c,
        OccurredAt__c,
        Operation__c,
        RecordId__c,
        Status__c,
        EventUuid__c
      FROM Log__c
      WHERE Source__c = 'LoggerServiceTest'
    ];

    System.assertEquals(2, logs.size(), 'Both queued events should become Log__c records');
    Map<String, Log__c> logsByMessage = new Map<String, Log__c>();
    for (Log__c logRecord : logs) {
      logsByMessage.put(logRecord.Message__c, logRecord);
      System.assertEquals('LoggerServiceTest', logRecord.Source__c);
      System.assertEquals('UNIT_TEST', logRecord.Operation__c);
      System.assertEquals(UserInfo.getUserId(), logRecord.UserId__c);
      System.assertEquals(UserInfo.getUserId(), logRecord.RecordId__c);
      System.assertEquals('New', logRecord.Status__c);
      System.assertNotEquals(null, logRecord.TransactionId__c);
      System.assertNotEquals(null, logRecord.OccurredAt__c);
      System.assertNotEquals(null, logRecord.EventUuid__c);
    }

    System.assertEquals('INFO', logsByMessage.get(marker + '-info').Level__c);
    System.assertEquals(null, logsByMessage.get(marker + '-info').ExceptionType__c);
    System.assertEquals('ERROR', logsByMessage.get(marker + '-error').Level__c);
    System.assertNotEquals(null, logsByMessage.get(marker + '-error').ExceptionType__c);
    System.assertNotEquals(null, logsByMessage.get(marker + '-error').StackTrace__c);
  }

  @IsTest
  static void overloadsApplyDefaultsAndEmptyFlushIsSafe() {
    String marker = 'logger-defaults-' + String.valueOf(DateTime.now().getTime());
    LoggerService logger = LoggerService.fromSource('LoggerServiceTest');

    Test.startTest();
    LoggerService.flush();
    logger.info(marker);
    LoggerService.flush();
    Test.getEventBus().deliver();
    Test.stopTest();

    List<Log__c> savedLogs = [
      SELECT Level__c, Message__c, Operation__c, RecordId__c
      FROM Log__c
      WHERE Source__c = 'LoggerServiceTest'
    ];
    System.assertEquals(1, savedLogs.size());
    Log__c savedLog = savedLogs[0];
    System.assertEquals('INFO', savedLog.Level__c);
    System.assertEquals(marker, savedLog.Message__c);
    System.assertEquals('UNSPECIFIED', savedLog.Operation__c);
    System.assertEquals(null, savedLog.RecordId__c);
  }
}
