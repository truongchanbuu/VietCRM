/** Exercises all seven native events without changing the opt-in Account trigger. */
@IsTest
private with sharing class TriggerToolkitNativeTest {
  @IsTest
  static void nativeEventsAndReadOnlyRestrictions() {
    List<Contact> records = new List<Contact>();
    for (Integer i = 0; i < 251; i++) {
      records.add(new Contact(LastName = 'Toolkit ' + i));
    }
    Test.startTest();
    insert as user records;
    Set<Id> ids = new Map<Id, Contact>(records).keySet();
    Integer edited = 0;
    for (Contact stored : [
      SELECT Description
      FROM Contact
      WHERE Id IN :ids
      WITH USER_MODE
    ]) {
      if (stored.Description == 'Native before edit') {
        edited++;
      }
    }
    Assert.areEqual(
      2,
      edited,
      'Before edits affect one original record per native batch'
    );
    for (Contact record : records) {
      record.LastName = 'Changed ' + record.LastName;
    }
    update as user records;
    update as user records;
    delete as user records;
    // Test-owned fixtures only; Apex undelete has no user-mode keyword.
    undelete records;
    Test.stopTest();
    for (System.TriggerOperation operation : System.TriggerOperation.values()) {
      Integer expected = records.size();
      if (
        operation == System.TriggerOperation.BEFORE_UPDATE ||
        operation == System.TriggerOperation.AFTER_UPDATE
      ) {
        expected *= 2;
      }
      Assert.areEqual(
        expected,
        TriggerToolkitProbe.totals.get(operation),
        'Dispatch every native record for ' + operation
      );
    }
    Assert.areEqual(
      records.size(),
      TriggerToolkitProbe.changedNames,
      'Second update has no changed names'
    );
  }
  @IsTest
  static void afterInsertIsReadOnly() {
    assertReadOnly(System.TriggerOperation.AFTER_INSERT, false);
  }
  @IsTest
  static void afterUpdateIsReadOnly() {
    assertReadOnly(System.TriggerOperation.AFTER_UPDATE, false);
  }
  @IsTest
  static void beforeDeleteIsReadOnly() {
    assertReadOnly(System.TriggerOperation.BEFORE_DELETE, true);
  }
  @IsTest
  static void afterDeleteIsReadOnly() {
    assertReadOnly(System.TriggerOperation.AFTER_DELETE, true);
  }
  @IsTest
  static void afterUndeleteIsReadOnly() {
    assertReadOnly(System.TriggerOperation.AFTER_UNDELETE, false);
  }
  @IsTest
  static void beforeUpdateOldIsReadOnly() {
    assertReadOnly(System.TriggerOperation.BEFORE_UPDATE, true);
  }
  @IsTest
  static void afterUpdateOldIsReadOnly() {
    assertReadOnly(System.TriggerOperation.AFTER_UPDATE, true);
  }

  private static void assertReadOnly(
    System.TriggerOperation operation,
    Boolean oldRecords
  ) {
    Contact record = new Contact(LastName = 'Read-only fixture');
    if (operation != System.TriggerOperation.AFTER_INSERT) {
      insert as user record;
    }
    if (operation == System.TriggerOperation.AFTER_UNDELETE) {
      delete as user record;
    }
    TriggerToolkitProbe.mutateAt = operation;
    TriggerToolkitProbe.mutateOld = oldRecords;
    Test.startTest();
    try {
      switch on operation {
        when AFTER_INSERT {
          insert as user record;
        }
        when BEFORE_UPDATE, AFTER_UPDATE {
          update as user record;
        }
        when BEFORE_DELETE, AFTER_DELETE {
          delete as user record;
        }
        // Test-owned fixture; Apex undelete has no user-mode keyword.
        when AFTER_UNDELETE {
          undelete record;
        }
      }
      Assert.fail('Expected native read-only DML failure for ' + operation);
    } catch (DmlException failure) {
      Assert.isTrue(
        failure.getMessage().contains('Record is read-only'),
        'Preserve the platform read-only restriction for ' + operation
      );
    }
    Test.stopTest();
  }
}
