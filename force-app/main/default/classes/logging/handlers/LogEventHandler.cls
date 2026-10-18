/** Routes the platform event trigger to its persistence service. */
public with sharing class LogEventHandler {
  /** Dispatches only LogEvent__e after-insert work. */
  public static void dispatch() {
    if (Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) {
      LogEventTriggerService.save(Trigger.new);
    }
  }
}
