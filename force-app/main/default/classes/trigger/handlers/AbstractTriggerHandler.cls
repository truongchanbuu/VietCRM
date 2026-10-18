/** Thin-trigger entry point. Override only the callbacks your object needs. */
public abstract with sharing class AbstractTriggerHandler {
  protected TriggerContext context { get; private set; }

  /** Dispatches exactly one callback using the active native trigger operation. */
  public void run() {
    dispatch(TriggerContext.current());
  }

  @TestVisible
  private void dispatch(TriggerContext invocation) {
    context = invocation;
    switch on context.operation {
      when BEFORE_INSERT {
        beforeInsert(context.getNewRecords());
      }
      when BEFORE_UPDATE {
        beforeUpdate(
          context.getNewRecords(),
          context.getNewMap(),
          context.getOldRecords(),
          context.getOldMap()
        );
      }
      when BEFORE_DELETE {
        beforeDelete(context.getOldRecords(), context.getOldMap());
      }
      when AFTER_INSERT {
        afterInsert(context.getNewRecords(), context.getNewMap());
      }
      when AFTER_UPDATE {
        afterUpdate(
          context.getNewRecords(),
          context.getNewMap(),
          context.getOldRecords(),
          context.getOldMap()
        );
      }
      when AFTER_DELETE {
        afterDelete(context.getOldRecords(), context.getOldMap());
      }
      when AFTER_UNDELETE {
        afterUndelete(context.getNewRecords(), context.getNewMap());
      }
    }
  }

  /** Optional before insert callback; defaults to no action. */
  protected virtual void beforeInsert(List<SObject> newRecords) {
  }

  /** Optional before update callback; defaults to no action. */
  protected virtual void beforeUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> newMap,
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
  }

  /** Optional before delete callback; defaults to no action. */
  protected virtual void beforeDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
  }

  /** Optional after insert callback; defaults to no action. */
  protected virtual void afterInsert(
    List<SObject> newRecords,
    Map<Id, SObject> newMap
  ) {
  }

  /** Optional after update callback; defaults to no action. */
  protected virtual void afterUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> newMap,
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
  }

  /** Optional after delete callback; defaults to no action. */
  protected virtual void afterDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
  }

  /** Optional after undelete callback; defaults to no action. */
  protected virtual void afterUndelete(
    List<SObject> newRecords,
    Map<Id, SObject> newMap
  ) {
  }
}
