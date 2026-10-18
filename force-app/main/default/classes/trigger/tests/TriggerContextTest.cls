/** Context availability, typed casts, native record edits, and field comparisons. */
@IsTest
private with sharing class TriggerContextTest {
  @IsTest
  static void collectionsMatchNativeAvailability() {
    Test.startTest();
    for (System.TriggerOperation operation : System.TriggerOperation.values()) {
      TriggerContext invocation = TriggerTestDataFactory.invocation(operation);
      Boolean deleting =
        operation == System.TriggerOperation.BEFORE_DELETE ||
        operation == System.TriggerOperation.AFTER_DELETE;
      Boolean updating =
        operation == System.TriggerOperation.BEFORE_UPDATE ||
        operation == System.TriggerOperation.AFTER_UPDATE;
      Assert.areEqual(operation, invocation.operation, 'Retain operation');
      Assert.areEqual(251, invocation.batchSize, 'Retain batch size');
      Assert.areEqual(
        Account.SObjectType,
        invocation.objectType,
        'Retain object type'
      );
      assertCollection(invocation, 'new', !deleting);
      assertCollection(
        invocation,
        'newMap',
        !deleting && operation != System.TriggerOperation.BEFORE_INSERT
      );
      assertCollection(invocation, 'old', updating || deleting);
      assertCollection(invocation, 'oldMap', updating || deleting);
    }
    Test.stopTest();
  }

  private static void assertCollection(
    TriggerContext invocation,
    String name,
    Boolean available
  ) {
    try {
      Object records;
      switch on name {
        when 'new' {
          records = invocation.getNewRecords();
        }
        when 'newMap' {
          records = invocation.getNewMap();
        }
        when 'old' {
          records = invocation.getOldRecords();
        }
        when 'oldMap' {
          records = invocation.getOldMap();
        }
      }
      Assert.isTrue(available, 'Unavailable Trigger.' + name + ' must throw');
      Assert.isNotNull(
        records,
        'Available collection must be native and non-null'
      );
    } catch (TriggerToolkitException failure) {
      Assert.isFalse(available, 'Available collection must not throw');
      Assert.areEqual(
        'Trigger.' + name + ' is unavailable for ' + invocation.operation + '.',
        failure.getMessage(),
        'Explain unavailable collection and operation'
      );
    }
  }

  @IsTest
  static void typedCastsRetainRecordEditsAndErrors() {
    TriggerContext invocation = TriggerTestDataFactory.invocation(
      System.TriggerOperation.BEFORE_UPDATE
    );
    Test.startTest();
    List<Account> accounts = (List<Account>) invocation.getNewRecords();
    Map<Id, Account> accountsById = (Map<Id, Account>) invocation.getNewMap();
    accounts[0].Description = 'Edited';
    accountsById.get(accounts[0].Id).addError('Rejected');
    Test.stopTest();
    Assert.areEqual(
      'Edited',
      invocation.getNewRecords()[0].get('Description'),
      'Retain edits'
    );
    Assert.isTrue(
      accounts[0] === accountsById.get(accounts[0].Id),
      'Retain map record identity'
    );
    Assert.areEqual(
      'Rejected',
      accounts[0].getErrors()[0].getMessage(),
      'Retain addError'
    );
  }

  @IsTest
  static void changesCompareByIdInNewRecordOrder() {
    List<Account> oldRecords = TriggerTestDataFactory.accounts(4);
    List<Account> newRecords = TriggerTestDataFactory.accounts(4);
    oldRecords[0].Description = 'old';
    newRecords[0].Description = 'new';
    oldRecords[1].Description = 'cleared';
    newRecords[2].Description = 'populated';
    List<Account> reordered = new List<Account>{
      newRecords[2],
      newRecords[3],
      newRecords[0],
      newRecords[1]
    };
    Test.startTest();
    for (
      System.TriggerOperation operation : new List<System.TriggerOperation>{
        System.TriggerOperation.BEFORE_UPDATE,
        System.TriggerOperation.AFTER_UPDATE
      }
    ) {
      TriggerContext invocation = new TriggerContext(
        operation,
        reordered,
        new Map<Id, Account>(reordered),
        oldRecords,
        new Map<Id, Account>(oldRecords)
      );
      List<SObject> changed = invocation.getChangedRecords(Account.Description);
      Assert.areEqual(
        new List<SObject>{ newRecords[2], newRecords[0], newRecords[1] },
        changed,
        'Detect value changes and both null transitions by ID in new order'
      );
      Assert.isTrue(
        newRecords[2] === changed[0],
        'Return original new record references'
      );
      Assert.areEqual(
        0,
        invocation.getChangedRecords(Account.Name).size(),
        'Equal values stay unchanged'
      );
      Assert.areEqual(
        0,
        invocation.getChangedRecords(Account.Phone).size(),
        'Null pairs stay unchanged'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void nullFieldFailsClearly() {
    assertInvalidField(null, 'must not be null');
  }

  @IsTest
  static void foreignFieldFailsClearly() {
    // Same API name on both objects must still be rejected.
    assertInvalidField(Contact.Description, 'must belong to Account');
  }

  private static void assertInvalidField(
    Schema.SObjectField field,
    String message
  ) {
    TriggerContext invocation = TriggerTestDataFactory.invocation(
      System.TriggerOperation.BEFORE_UPDATE
    );
    Test.startTest();
    try {
      invocation.getChangedRecords(field);
      Assert.fail('Expected invalid field to throw');
    } catch (TriggerToolkitException failure) {
      Assert.isTrue(
        failure.getMessage().contains(message),
        'Explain invalid comparison field'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void nonUpdateEventsRejectComparisons() {
    Test.startTest();
    for (System.TriggerOperation operation : System.TriggerOperation.values()) {
      if (
        operation == System.TriggerOperation.BEFORE_UPDATE ||
        operation == System.TriggerOperation.AFTER_UPDATE
      ) {
        continue;
      }
      try {
        TriggerTestDataFactory.invocation(operation)
          .getChangedRecords(Account.Name);
        Assert.fail('Expected non-update rejection for ' + operation);
      } catch (TriggerToolkitException failure) {
        Assert.areEqual(
          'Field comparisons require an update event.',
          failure.getMessage(),
          'Explain update-only contract'
        );
      }
    }
    Test.stopTest();
  }

  @IsTest
  static void currentOutsideTriggerFailsClearly() {
    Test.startTest();
    try {
      TriggerContext.current();
      Assert.fail('Expected active-trigger requirement');
    } catch (TriggerToolkitException failure) {
      Assert.isTrue(
        failure.getMessage().contains('active trigger execution'),
        'Explain execution requirement'
      );
    }
    Test.stopTest();
  }
}
