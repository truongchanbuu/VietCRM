/** Synthetic, typed fixtures; no org data or database work. */
@IsTest
public with sharing class TriggerTestDataFactory {
  public static List<Account> accounts(Integer count) {
    String keyPrefix = Account.SObjectType.getDescribe(
        SObjectDescribeOptions.DEFERRED
      )
      .getKeyPrefix();
    List<Account> records = new List<Account>();
    for (Integer i = 1; i <= count; i++) {
      // Construct fixture IDs from the schema prefix, never a real org record ID.
      Id recordId = (Id) (keyPrefix + String.valueOf(i).leftPad(12, '0'));
      records.add(new Account(Id = recordId, Name = 'Account ' + i));
    }
    return records;
  }

  public static TriggerContext invocation(System.TriggerOperation operation) {
    Boolean deleting =
      operation == System.TriggerOperation.BEFORE_DELETE ||
      operation == System.TriggerOperation.AFTER_DELETE;
    Boolean updating =
      operation == System.TriggerOperation.BEFORE_UPDATE ||
      operation == System.TriggerOperation.AFTER_UPDATE;
    List<Account> newRecords = deleting ? null : accounts(251);
    List<Account> oldRecords = deleting || updating ? accounts(251) : null;
    Map<Id, Account> newMap = deleting ||
      operation == System.TriggerOperation.BEFORE_INSERT
      ? null
      : new Map<Id, Account>(newRecords);
    Map<Id, Account> oldMap = oldRecords == null
      ? null
      : new Map<Id, Account>(oldRecords);
    return new TriggerContext(
      operation,
      newRecords,
      newMap,
      oldRecords,
      oldMap
    );
  }
}
