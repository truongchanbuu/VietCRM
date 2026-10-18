/** Validation-only Contact handler; never install this instrumentation in an application. */
public with sharing class TriggerToolkitProbe extends AbstractTriggerHandler {
  @TestVisible
  private static Map<System.TriggerOperation, Integer> totals = new Map<System.TriggerOperation, Integer>();
  @TestVisible
  private static Integer changedNames = 0;
  @TestVisible
  private static System.TriggerOperation mutateAt;
  @TestVisible
  private static Boolean mutateOld = false;

  private void observe() {
    Integer previous = totals.get(context.operation);
    totals.put(
      context.operation,
      (previous == null ? 0 : previous) + context.batchSize
    );
    Assert.areEqual(
      Contact.SObjectType,
      context.objectType,
      'Capture native object type'
    );
    Assert.areEqual(
      Trigger.size,
      context.batchSize,
      'Capture native batch size'
    );
    Assert.areEqual(
      Trigger.operationType,
      context.operation,
      'Capture native operation'
    );
    if (Trigger.new != null) {
      Assert.isTrue(
        context.getNewRecords() === Trigger.new,
        'Retain native new records'
      );
    }
    if (Trigger.newMap != null) {
      Assert.isTrue(
        context.getNewMap() === Trigger.newMap,
        'Retain native new map'
      );
    }
    if (Trigger.old != null) {
      Assert.isTrue(
        context.getOldRecords() === Trigger.old,
        'Retain native old records'
      );
      Assert.isTrue(
        context.getOldMap() === Trigger.oldMap,
        'Retain native old map'
      );
    }
    if (context.operation == mutateAt) {
      // Read-only violations fail the DML operation; the integration caller asserts the error.
      SObject record = mutateOld
        ? context.getOldRecords()[0]
        : context.getNewRecords()[0];
      record.put(Contact.Description, 'Must not persist');
    }
  }

  protected override void beforeInsert(List<SObject> newRecords) {
    observe();
    Assert.isTrue(newRecords === Trigger.new, 'Keep native new list');
    List<Contact> contacts = (List<Contact>) newRecords;
    contacts[0].Description = 'Native before edit';
  }

  protected override void beforeUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> newMap,
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    observe();
    Map<Id, Contact> contacts = (Map<Id, Contact>) newMap;
    Assert.isTrue(
      contacts.get(newRecords[0].Id) === newRecords[0],
      'Typed map retains record identity'
    );
    changedNames += context.getChangedRecords(Contact.LastName).size();
  }

  protected override void beforeDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    observe();
  }

  protected override void afterInsert(
    List<SObject> newRecords,
    Map<Id, SObject> newMap
  ) {
    observe();
  }

  protected override void afterUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> newMap,
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    observe();
  }

  protected override void afterDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    observe();
  }

  protected override void afterUndelete(
    List<SObject> newRecords,
    Map<Id, SObject> newMap
  ) {
    observe();
  }
}
