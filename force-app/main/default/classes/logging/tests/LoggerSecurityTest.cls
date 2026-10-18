/** Verifies producer and reader boundaries with isolated test-only permission grants. */
@IsTest
private with sharing class LoggerSecurityTest {
  @IsTest
  static void readerCannotReadDeniedMessageField() {
    User reader = LoggerTestDataFactory.createUser('LoggerReadLimited');
    System.runAs(reader) {
      Test.startTest();
      Assert.isTrue(
        Log__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
          .isAccessible(),
        'Fixture grants stored-log read access'
      );
      Assert.isFalse(
        Log__c.Message__c.getDescribe().isAccessible(),
        'Fixture denies stored message access'
      );
      try {
        List<Log__c> logs = [SELECT Message__c FROM Log__c WITH USER_MODE];
        Assert.fail(
          'Denied message field must not be queryable; returned rows: ' +
          logs.size()
        );
      } catch (QueryException expected) {
        Assert.isFalse(
          Log__c.Message__c.getDescribe().isAccessible(),
          'User-mode queries enforce stored-log field access'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void minimumUserCannotPublish() {
    User producer = LoggerTestDataFactory.createUser(null);
    System.runAs(producer) {
      Test.startTest();
      LoggerService.fromSource('Denied').info('Private message');
      LogFlushResult report = LoggerService.flushWithResult();
      LoggerService.flush();
      Test.stopTest();
      Assert.areEqual(0, report.acceptedCount, 'No publish permission');
      Assert.areEqual(1, report.rejectedCount, 'Denied entry remains pending');
      Assert.areEqual(
        new List<String>{ 'INSUFFICIENT_ACCESS' },
        report.outcomes[0].errorCodes,
        'Sanitized denial'
      );
    }
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Log__c WITH SYSTEM_MODE],
      'Denied producer creates no logs'
    );
  }

  @IsTest
  static void publisherCanPublishWithoutStoredLogAccess() {
    User producer = LoggerTestDataFactory.createUser('LoggerPublish');
    System.runAs(producer) {
      Test.startTest();
      LoggerService.fromSource('Publisher').info('Allowed');
      LogFlushResult report = LoggerService.flushWithResult();
      Test.getEventBus().deliver();
      Test.stopTest();
      Assert.areEqual(1, report.acceptedCount, 'Explicit publisher grant');
      try {
        List<Log__c> logs = [SELECT Id FROM Log__c WITH USER_MODE];
        Assert.fail(
          'Publisher must not read stored logs; returned rows: ' + logs.size()
        );
      } catch (QueryException expected) {
        Assert.isFalse(
          Log__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
            .isAccessible(),
          'Publisher has no log read CRUD'
        );
      }
    }
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Log__c WITH SYSTEM_MODE],
      'Trusted sink saves independently of producer CRUD'
    );
  }

  @IsTest
  static void readerCanReadButCannotPublish() {
    User reader = LoggerTestDataFactory.createUser('LoggerRead');
    Test.startTest();
    Database.SaveResult published = EventBus.publish(
      LoggerTestDataFactory.eventRecord('Reader visibility')
    );
    Assert.isTrue(published.isSuccess(), 'Fixture event must be accepted');
    Test.getEventBus().deliver();
    System.runAs(reader) {
      List<Log__c> logs = [SELECT Message__c FROM Log__c WITH USER_MODE];
      LoggerService.fromSource('Reader').info('Denied');
      LogFlushResult report = LoggerService.flushWithResult();
      Test.stopTest();
      Assert.areEqual(
        1,
        logs.size(),
        'Trusted reader can see the sink-owned log'
      );
      Assert.areEqual(
        'Reader visibility',
        logs[0].Message__c,
        'Reader field access'
      );
      Assert.areEqual(
        1,
        report.rejectedCount,
        'Reader grant does not permit publishing'
      );
      Assert.isFalse(
        Log__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
          .isCreateable(),
        'Reader cannot create logs directly'
      );
    }
  }
}
