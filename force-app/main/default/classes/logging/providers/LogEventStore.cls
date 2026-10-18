/** Trusted event sink; system-mode writes are independent of producer Log__c CRUD. */
public with sharing class LogEventStore {
  /**
   * Maps only the actual event trigger batch, then performs one partial insert.
   * @param events The unmodified LogEvent__e after-insert trigger batch.
   * @return Ordered database results after deduplicating nonblank batch UUIDs.
   * @throws LoggerException if called outside the matching event trigger context.
   */
  public static List<Database.SaveResult> insertEvents(
    List<LogEvent__e> events
  ) {
    if (
      !Trigger.isExecuting ||
      !Trigger.isAfter ||
      !Trigger.isInsert ||
      Trigger.new == null ||
      Trigger.new.isEmpty() ||
      Trigger.new[0].getSObjectType() != LogEvent__e.SObjectType ||
      events != Trigger.new
    ) {
      throw new LoggerException(
        'Log persistence requires the log event trigger batch.'
      );
    }
    return insertMappedEvents(events);
  }

  @TestVisible
  private static List<Database.SaveResult> insertMappedEvents(
    List<LogEvent__e> events
  ) {
    List<Log__c> logs = new List<Log__c>();
    Set<String> seen = new Set<String>();
    for (LogEvent__e eventRecord : events) {
      if (
        String.isNotBlank(eventRecord.EventUuid) &&
        !seen.add(eventRecord.EventUuid)
      ) {
        continue;
      }
      logs.add(LogEventTriggerService.fromEvent(eventRecord));
    }
    // Intentional privilege boundary: a producer may publish but cannot write/read stored logs.
    return Database.insert(logs, false, AccessLevel.SYSTEM_MODE);
  }
}
