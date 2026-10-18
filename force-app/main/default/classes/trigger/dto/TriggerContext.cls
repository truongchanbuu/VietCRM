/** One invocation's native trigger collections, retaining platform mutation rules. */
public with sharing class TriggerContext {
  public System.TriggerOperation operation { get; private set; }
  public Integer batchSize { get; private set; }
  public Schema.SObjectType objectType { get; private set; }
  private List<SObject> newRecords;
  private Map<Id, SObject> newMap;
  private List<SObject> oldRecords;
  private Map<Id, SObject> oldMap;

  @TestVisible
  private TriggerContext(
    System.TriggerOperation operation,
    List<SObject> newRecords,
    Map<Id, SObject> newMap,
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    this.operation = operation;
    this.newRecords = newRecords;
    this.newMap = newMap;
    this.oldRecords = oldRecords;
    this.oldMap = oldMap;
    List<SObject> records = newRecords == null ? oldRecords : newRecords;
    this.batchSize = records.size();
    this.objectType = records.getSObjectType();
  }

  /** Captures references only; unavailable collections remain unavailable. */
  public static TriggerContext current() {
    if (!Trigger.isExecuting) {
      throw new TriggerToolkitException(
        'Trigger context requires active trigger execution.'
      );
    }
    return new TriggerContext(
      Trigger.operationType,
      Trigger.new,
      Trigger.newMap,
      Trigger.old,
      Trigger.oldMap
    );
  }

  /** @return Native new records; unavailable for delete. */
  public List<SObject> getNewRecords() {
    if (newRecords == null) {
      throw new TriggerToolkitException(
        'Trigger.new is unavailable for ' + operation + '.'
      );
    }
    return newRecords;
  }

  /** @return Native new map; unavailable before insert and for delete. */
  public Map<Id, SObject> getNewMap() {
    if (newMap == null) {
      throw new TriggerToolkitException(
        'Trigger.newMap is unavailable for ' + operation + '.'
      );
    }
    return newMap;
  }

  /** @return Native old records; available only for update and delete. */
  public List<SObject> getOldRecords() {
    if (oldRecords == null) {
      throw new TriggerToolkitException(
        'Trigger.old is unavailable for ' + operation + '.'
      );
    }
    return oldRecords;
  }

  /** @return Native old map; available only for update and delete. */
  public Map<Id, SObject> getOldMap() {
    if (oldMap == null) {
      throw new TriggerToolkitException(
        'Trigger.oldMap is unavailable for ' + operation + '.'
      );
    }
    return oldMap;
  }

  /**
   * Compares by ID, including null transitions, in new-record order.
   * @param field A field belonging to this invocation's object
   * @return Matching native new records in a new list
   */
  public List<SObject> getChangedRecords(Schema.SObjectField field) {
    if (
      operation != System.TriggerOperation.BEFORE_UPDATE &&
      operation != System.TriggerOperation.AFTER_UPDATE
    ) {
      throw new TriggerToolkitException(
        'Field comparisons require an update event.'
      );
    }
    if (field == null) {
      throw new TriggerToolkitException('Comparison field must not be null.');
    }
    String fieldName = field.getDescribe().getName();
    if (objectType.getDescribe().fields.getMap().get(fieldName) != field) {
      throw new TriggerToolkitException(
        'Comparison field must belong to ' + objectType + '.'
      );
    }
    List<SObject> changed = new List<SObject>();
    for (SObject record : newRecords) {
      if (record.get(field) != oldMap.get(record.Id).get(field)) {
        changed.add(record);
      }
    }
    return changed;
  }
}
