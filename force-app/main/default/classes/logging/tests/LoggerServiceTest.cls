/** Verifies buffering, request outcomes, and actual event persistence. */
@IsTest
private with sharing class LoggerServiceTest {
  @IsTest
  static void bulkFlushPersistsAllSources() {
    Integer count = 251;
    Set<String> expected = new Set<String>();
    Test.startTest();
    for (Integer i = 0; i < count; i++) {
      String message = 'Bulk ' + i;
      expected.add(message);
      LoggerService.fromSource(
          Math.mod(i, 2) == 0 ? 'FirstSource' : 'SecondSource'
        )
        .info(message);
    }
    LogFlushResult report = LoggerService.flushWithResult();
    Test.getEventBus().deliver();
    LogFlushResult repeated = LoggerService.flushWithResult();
    Test.stopTest();
    Assert.areEqual(
      count,
      report.acceptedCount,
      'Every request should be accepted'
    );
    Assert.areEqual(0, report.rejectedCount, 'No request should fail');
    Assert.areEqual(
      0,
      repeated.outcomes.size(),
      'Accepted events must leave the buffer'
    );
    List<Log__c> logs = [
      SELECT Message__c, Source__c, Operation__c, EventUuid__c
      FROM Log__c
      WITH SYSTEM_MODE
    ];
    Set<String> actual = new Set<String>();
    Set<String> uuids = new Set<String>();
    Set<String> sources = new Set<String>();
    for (Log__c logRecord : logs) {
      actual.add(logRecord.Message__c);
      uuids.add(logRecord.EventUuid__c);
      sources.add(logRecord.Source__c);
      Assert.areEqual(
        'UNSPECIFIED',
        logRecord.Operation__c,
        'Default operation must survive delivery'
      );
    }
    Assert.areEqual(expected, actual, 'Exact population must survive delivery');
    Assert.areEqual(count, logs.size(), 'No duplicate database records');
    Assert.areEqual(count, uuids.size(), 'Each event should have its own UUID');
    Assert.areEqual(
      new Set<String>{ 'FirstSource', 'SecondSource' },
      sources,
      'Both sources share the buffer'
    );
  }

  @IsTest
  static void overloadsPreserveExceptionAndContext() {
    Exception captured;
    try {
      Integer invalid = 1 / 0;
      Assert.fail('Expected a math exception, received: ' + invalid);
    } catch (MathException failure) {
      captured = failure;
    }
    LoggerService logger = LoggerService.fromSource('Overloads');
    Test.startTest();
    logger.info('Info', 'READ', UserInfo.getUserId(), null);
    logger.error(null, captured);
    logger.error('Error', 'WRITE', UserInfo.getUserId());
    logger.error('Full', 'WRITE', UserInfo.getUserId(), captured);
    LoggerService.flush();
    Test.getEventBus().deliver();
    Test.stopTest();
    List<Log__c> logs = [
      SELECT
        Message__c,
        Level__c,
        ExceptionType__c,
        StackTrace__c,
        RecordId__c,
        UserId__c,
        TransactionId__c,
        OccurredAt__c,
        Status__c
      FROM Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(4, logs.size(), 'Every overload should produce a log');
    Map<String, Log__c> byMessage = new Map<String, Log__c>();
    for (Log__c logRecord : logs) {
      byMessage.put(logRecord.Message__c, logRecord);
      Assert.areEqual(
        UserInfo.getUserId(),
        logRecord.UserId__c,
        'Producer identity must be retained'
      );
      Assert.areEqual(
        Request.getCurrent().getRequestId(),
        logRecord.TransactionId__c,
        'Request correlation must survive'
      );
      Assert.areNotEqual(
        null,
        logRecord.OccurredAt__c,
        'Producer timestamp is required'
      );
      Assert.areEqual(
        'New',
        logRecord.Status__c,
        'Default status must survive'
      );
    }
    Assert.areEqual('INFO', byMessage.get('Info').Level__c, 'Info severity');
    Assert.areEqual(
      UserInfo.getUserId(),
      byMessage.get('Info').RecordId__c,
      'Record context'
    );
    Log__c exceptionLog = byMessage.get(captured.getMessage());
    Assert.areEqual(
      captured.getTypeName(),
      exceptionLog.ExceptionType__c,
      'Exception fallback message and type'
    );
    Assert.areEqual(
      captured.getStackTraceString(),
      exceptionLog.StackTrace__c,
      'Exception stack'
    );
  }

  @IsTest
  static void rejectedEntriesCanBeRetriedWithoutResendingAcceptedEntries() {
    ControlledPublisher fake = new ControlledPublisher();
    LoggerService.publisher = fake;
    LoggerService logger = LoggerService.fromSource('Retry');
    Test.startTest();
    logger.info('Accepted');
    logger.info('Rejected');
    LogFlushResult first = LoggerService.flushWithResult();
    fake.rejectSecond = false;
    LogFlushResult retry = LoggerService.flushWithResult();
    Test.stopTest();
    Assert.areEqual(1, first.acceptedCount, 'First request accepted');
    Assert.areEqual(1, first.rejectedCount, 'Second request retained');
    Assert.areEqual(
      new List<String>{ 'REQUIRED_FIELD_MISSING' },
      first.outcomes[1].errorCodes,
      'Only sanitized codes'
    );
    Assert.areEqual(
      1,
      retry.acceptedCount,
      'Retry must contain only the rejected event'
    );
    Assert.areEqual(
      first.outcomes[1].eventUuid,
      retry.outcomes[0].eventUuid,
      'Explicit retry keeps identity'
    );
    Assert.areEqual(2, fake.calls, 'One boundary call per flush');
    Assert.isFalse(
      JSON.serialize(first).contains('PRIVATE_PAYLOAD'),
      'Failure reports must omit payloads'
    );
  }

  @IsTest
  static void emptyFlushDoesNotPublish() {
    ControlledPublisher fake = new ControlledPublisher();
    LoggerService.publisher = fake;
    Test.startTest();
    LoggerService.flush();
    Test.stopTest();
    Assert.areEqual(
      0,
      fake.calls,
      'Empty flush must avoid the platform boundary'
    );
  }

  @IsTest
  static void publisherNullInputReturnsEmptyReport() {
    Test.startTest();
    LogFlushResult report = new LogEventPublisher().publish(null);
    Test.stopTest();
    Assert.areEqual(
      0,
      report.outcomes.size(),
      'Null boundary input has no requests'
    );
  }

  @IsTest
  static void publishExceptionIsSanitizedAndRetained() {
    LoggerService.publisher = new FailingPublisher();
    Test.startTest();
    LoggerService.fromSource('Failure').info('Private diagnostic');
    LogFlushResult report = LoggerService.flushWithResult();
    LoggerService.publisher = new ControlledPublisher();
    LogFlushResult retry = LoggerService.flushWithResult();
    Test.stopTest();
    Assert.areEqual(
      1,
      report.rejectedCount,
      'Handled publish exception rejects the request'
    );
    Assert.areEqual(
      new List<String>{ 'PUBLISH_EXCEPTION' },
      report.outcomes[0].errorCodes,
      'Publish exception is sanitized'
    );
    Assert.isFalse(
      JSON.serialize(report).contains('PRIVATE_PAYLOAD'),
      'Exception details must not escape'
    );
    Assert.areEqual(
      1,
      retry.acceptedCount,
      'Rejected request remains available for an explicit retry'
    );
  }

  @IsTest
  static void invalidRecordIdentifierIsRejectedBeforeQueuing() {
    Test.startTest();
    try {
      LoggerService.fromSource('Invalid')
        .error('Message', 'WRITE', 'not-an-id');
      Assert.fail('Invalid identifier must be rejected');
    } catch (LoggerException expected) {
      Assert.areEqual(
        'Record identifier must be a Salesforce Id.',
        expected.getMessage(),
        'Sanitized validation error'
      );
    }
    Assert.areEqual(
      0,
      LoggerService.flushWithResult().outcomes.size(),
      'Invalid entry must not enter the buffer'
    );
    Test.stopTest();
  }

  @IsTest
  static void textIsTruncatedToEventFieldLengths() {
    String longSource = 'x'
      .repeat(LogEvent__e.Source__c.getDescribe().getLength() + 1);
    String longMessage = 'm'
      .repeat(LogEvent__e.Message__c.getDescribe().getLength() + 1);
    Test.startTest();
    LoggerService.fromSource(longSource)
      .info(longMessage, longSource, null, null);
    LoggerService.flush();
    Test.getEventBus().deliver();
    Test.stopTest();
    Log__c saved = [
      SELECT Source__c, Message__c, Operation__c
      FROM Log__c
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.areEqual(
      LogEvent__e.Source__c.getDescribe().getLength(),
      saved.Source__c.length(),
      'Source length'
    );
    Assert.areEqual(
      LogEvent__e.Message__c.getDescribe().getLength(),
      saved.Message__c.length(),
      'Message length'
    );
    Assert.areEqual(
      LogEvent__e.Operation__c.getDescribe().getLength(),
      saved.Operation__c.length(),
      'Operation length'
    );
  }

  private with sharing class ControlledPublisher extends LogEventPublisher {
    Boolean rejectSecond = true;
    Integer calls = 0;
    protected override List<Database.SaveResult> enqueue(
      List<LogEvent__e> events
    ) {
      calls++;
      List<Database.SaveResult> results = new List<Database.SaveResult>();
      for (Integer i = 0; i < events.size(); i++) {
        results.add(
          LoggerTestDataFactory.result(
            rejectSecond && i == 1 ? 'REQUIRED_FIELD_MISSING' : null,
            new List<String>()
          )
        );
      }
      return results;
    }
  }

  private with sharing class FailingPublisher extends LogEventPublisher {
    protected override List<Database.SaveResult> enqueue(
      List<LogEvent__e> events
    ) {
      throw new DmlException('PRIVATE_PAYLOAD');
    }
  }
}
