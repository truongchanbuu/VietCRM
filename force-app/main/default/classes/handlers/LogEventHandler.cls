public class LogEventHandler {
  public static void dispatch() {
    switch on Trigger.operationType {
      when AFTER_INSERT {
        onAfterUpdate(Trigger.new);
      }
    }
  }

  private static void onAfterUpdate(List<LogEvent__e> events) {
    LogEventTriggerService.save(events);
  }
}
