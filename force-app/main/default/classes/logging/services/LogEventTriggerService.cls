/** Coordinates event persistence and bounded retry handling. */
public with sharing class LogEventTriggerService {
  private static final Integer MAX_RETRIES = 3;

  /**
   * Saves the actual event trigger batch; empty inputs perform no work.
   * @param events Unmodified LogEvent__e after-insert trigger batch.
   */
  public static void save(List<LogEvent__e> events) {
    if (events == null || events.isEmpty()) {
      return;
    }
    List<Database.SaveResult> results = LogEventStore.insertEvents(events);
    handleResults(
      results,
      EventBus.TriggerContext.currentContext().retries,
      Log__c.EventUuid__c.getDescribe().isUnique()
    );
  }

  /**
   * Pure schema mapping; developers adapt these fields with the producer fields.
   * @param eventRecord Event to map, without database access.
   * @return An unsaved log record.
   * @throws LoggerException if the event is null.
   */
  public static Log__c fromEvent(LogEvent__e eventRecord) {
    if (eventRecord == null) {
      throw new LoggerException('A log event is required.');
    }
    return new Log__c(
      EventUuid__c = eventRecord.EventUuid,
      Level__c = eventRecord.Level__c,
      Message__c = eventRecord.Message__c,
      Source__c = eventRecord.Source__c,
      ExceptionType__c = eventRecord.ExceptionType__c,
      StackTrace__c = eventRecord.StackTrace__c,
      TransactionId__c = eventRecord.TransactionId__c,
      UserId__c = eventRecord.UserId__c,
      OccurredAt__c = eventRecord.OccurredAt__c,
      Operation__c = eventRecord.Operation__c,
      RecordId__c = eventRecord.RecordId__c,
      Status__c = eventRecord.Status__c
    );
  }

  @TestVisible
  private static Set<String> handleResults(
    List<Database.SaveResult> results,
    Integer retries,
    Boolean uniqueUuid
  ) {
    Integer failedCount = 0;
    Set<String> codes = new Set<String>();
    for (Database.SaveResult result : results) {
      for (Database.Error failure : result.getErrors()) {
        // Other unique constraints or duplicate rules must not be mistaken for redelivery.
        if (
          uniqueUuid &&
          failure.getStatusCode() == StatusCode.DUPLICATE_VALUE &&
          failure.getFields().contains('EventUuid__c')
        ) {
          continue;
        }
        failedCount++;
        codes.add(String.valueOf(failure.getStatusCode()));
      }
    }
    if (failedCount == 0) {
      return codes;
    }
    if (codes.contains('UNABLE_TO_LOCK_ROW') && retries < MAX_RETRIES) {
      throw new EventBus.RetryableException(
        'Temporary lock while saving logs; retrying event batch.'
      );
    }
    // Terminal fallback only: do not publish another event or expose failed payloads.
    System.debug(
      LoggingLevel.ERROR,
      'Logger persistence errors: ' +
        failedCount +
        '; codes: ' +
        String.join(new List<String>(codes), ', ')
    );
    return codes;
  }
}
