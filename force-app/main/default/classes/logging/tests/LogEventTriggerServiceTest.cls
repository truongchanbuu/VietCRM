/** Exercises event mapping, partial persistence, and retry classification. */
@IsTest
private with sharing class LogEventTriggerServiceTest {
  @IsTest
  static void fullEventBatchKeepsValidRows() {
    Integer batchSize = 2000;
    List<LogEvent__e> events = new List<LogEvent__e>();
    Set<String> expected = new Set<String>();
    for (Integer i = 0; i < batchSize; i++) {
      LogEvent__e eventRecord = LoggerTestDataFactory.eventRecord('Batch ' + i);
      if (Math.mod(i, 2) == 0) {
        eventRecord.TransactionId__c = null;
      } else {
        expected.add(eventRecord.Message__c);
      }
      events.add(eventRecord);
    }
    Test.startTest();
    // Apex tests can publish at most 500 events; exercise a full subscriber batch at the store boundary.
    List<Database.SaveResult> results = LogEventStore.insertMappedEvents(
      events
    );
    Assert.areEqual(
      1,
      Limits.getDmlStatements(),
      'A full subscriber batch uses one insert'
    );
    Integer accepted = 0;
    for (Database.SaveResult result : results) {
      if (result.isSuccess()) {
        accepted++;
      }
    }
    Test.stopTest();
    Assert.areEqual(
      expected.size(),
      accepted,
      'Partial results match the valid population'
    );
    List<Log__c> logs = [SELECT Message__c FROM Log__c WITH SYSTEM_MODE];
    Set<String> actual = new Set<String>();
    for (Log__c logRecord : logs) {
      actual.add(logRecord.Message__c);
    }
    Assert.areEqual(
      expected.size(),
      logs.size(),
      'Valid rows survive permanent failures'
    );
    Assert.areEqual(expected, actual, 'Exact valid population persists');
  }

  @IsTest
  static void eventTriggerKeepsValidRows() {
    Integer batchSize = 252;
    List<LogEvent__e> events = new List<LogEvent__e>();
    for (Integer i = 0; i < batchSize; i++) {
      LogEvent__e eventRecord = LoggerTestDataFactory.eventRecord(
        'Delivery ' + i
      );
      if (Math.mod(i, 2) == 0) {
        eventRecord.TransactionId__c = null;
      }
      events.add(eventRecord);
    }
    Test.startTest();
    List<Database.SaveResult> published = EventBus.publish(events);
    Test.getEventBus().deliver();
    Test.stopTest();
    for (Database.SaveResult result : published) {
      Assert.isTrue(
        result.isSuccess(),
        'Optional event field must reach the subscriber'
      );
    }
    Assert.areEqual(
      batchSize / 2,
      [SELECT COUNT() FROM Log__c WITH SYSTEM_MODE],
      'Actual subscriber preserves valid rows'
    );
  }

  @IsTest
  static void batchDeduplicatesSameEventIdentity() {
    LogEvent__e eventRecord = LoggerTestDataFactory.eventRecord('Duplicate');
    Test.startTest();
    List<Database.SaveResult> results = LogEventStore.insertMappedEvents(
      new List<LogEvent__e>{ eventRecord, eventRecord }
    );
    Test.stopTest();
    Assert.areEqual(
      1,
      results.size(),
      'Repeated batch UUID produces one insert result'
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Log__c WITH SYSTEM_MODE],
      'Repeated batch UUID is stored once'
    );
  }

  @IsTest
  static void mappingRetainsEventIdentity() {
    LogEvent__e eventRecord = LoggerTestDataFactory.eventRecord('Mapping');
    Test.startTest();
    Log__c mapped = LogEventTriggerService.fromEvent(eventRecord);
    Test.stopTest();
    Assert.areEqual(
      eventRecord.EventUuid,
      mapped.EventUuid__c,
      'Identity mapping'
    );
    Assert.areEqual(
      eventRecord.Operation__c,
      mapped.Operation__c,
      'Operation mapping'
    );
    Assert.areEqual(
      eventRecord.Message__c,
      mapped.Message__c,
      'Message mapping'
    );
  }

  @IsTest
  static void nullMappingIsRejected() {
    Test.startTest();
    try {
      LogEventTriggerService.fromEvent(null);
      Assert.fail('Null mapping must be rejected');
    } catch (LoggerException expected) {
      Assert.areEqual(
        'A log event is required.',
        expected.getMessage(),
        'Explicit null contract'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void nullBatchDoesNoWork() {
    Test.startTest();
    LogEventTriggerService.save(null);
    Assert.areEqual(
      0,
      Limits.getDmlStatements(),
      'Null input must not perform DML'
    );
    Test.stopTest();
  }

  @IsTest
  static void emptyBatchDoesNoWork() {
    Test.startTest();
    LogEventTriggerService.save(new List<LogEvent__e>());
    Assert.areEqual(
      0,
      Limits.getDmlStatements(),
      'Empty input must not perform DML'
    );
    Test.stopTest();
  }

  @IsTest
  static void directPersistenceIsDenied() {
    Test.startTest();
    try {
      LogEventTriggerService.save(
        new List<LogEvent__e>{ LoggerTestDataFactory.eventRecord('Denied') }
      );
      Assert.fail('Direct persistence must be denied');
    } catch (LoggerException expected) {
      Assert.areEqual(
        'Log persistence requires the log event trigger batch.',
        expected.getMessage(),
        'Trusted boundary'
      );
    }
    Assert.areEqual(
      0,
      Limits.getDmlStatements(),
      'Denied calls must have no write side effects'
    );
    Test.stopTest();
  }

  @IsTest
  static void rowLockRequestsRetry() {
    Test.startTest();
    try {
      LogEventTriggerService.handleResults(
        new List<Database.SaveResult>{
          LoggerTestDataFactory.result('UNABLE_TO_LOCK_ROW', new List<String>())
        },
        0,
        false
      );
      Assert.fail('Transient lock must request a batch retry');
    } catch (EventBus.RetryableException expected) {
      Assert.isTrue(
        expected.getMessage().contains('retrying event batch'),
        'Retry reason must be sanitized'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void exhaustedRetriesDoNotRetry() {
    Test.startTest();
    LogEventTriggerService.handleResults(
      new List<Database.SaveResult>{
        LoggerTestDataFactory.result('UNABLE_TO_LOCK_ROW', new List<String>())
      },
      3,
      false
    );
    Test.stopTest();
    Assert.areEqual(
      0,
      Limits.getDmlStatements(),
      'Terminal diagnostics must not recurse into persistence'
    );
  }

  @IsTest
  static void uniqueUuidDuplicateIsRecognized() {
    Test.startTest();
    Set<String> codes = LogEventTriggerService.handleResults(
      new List<Database.SaveResult>{
        LoggerTestDataFactory.result(
          'DUPLICATE_VALUE',
          new List<String>{ 'EventUuid__c' }
        )
      },
      0,
      true
    );
    Test.stopTest();
    Assert.areEqual(
      new Set<String>(),
      codes,
      'UUID duplicates are already persisted'
    );
  }

  @IsTest
  static void unrelatedDuplicateRemainsAFailure() {
    Test.startTest();
    Set<String> codes = LogEventTriggerService.handleResults(
      new List<Database.SaveResult>{
        LoggerTestDataFactory.result(
          'DUPLICATE_VALUE',
          new List<String>{ 'Name' }
        )
      },
      0,
      true
    );
    Test.stopTest();
    Assert.areEqual(
      new Set<String>{ 'DUPLICATE_VALUE' },
      codes,
      'Only the UUID constraint establishes redelivery'
    );
  }

  @IsTest
  static void nonUniqueUuidCannotEstablishRedelivery() {
    Test.startTest();
    Set<String> codes = LogEventTriggerService.handleResults(
      new List<Database.SaveResult>{
        LoggerTestDataFactory.result(
          'DUPLICATE_VALUE',
          new List<String>{ 'EventUuid__c' }
        )
      },
      0,
      false
    );
    Test.stopTest();
    Assert.areEqual(
      new Set<String>{ 'DUPLICATE_VALUE' },
      codes,
      'Schema uniqueness is required for redelivery classification'
    );
  }
}
