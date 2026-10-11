public with sharing class CaseHandler {
  public static void dispatch() {
    switch on Trigger.operationType {
      when AFTER_UPDATE {
        CaseService.afterUpdate(
          (List<Case>) Trigger.new,
          (Map<Id, Case>) Trigger.oldMap
        );
      }
      when else {
        return;
      }
    }
  }
}
