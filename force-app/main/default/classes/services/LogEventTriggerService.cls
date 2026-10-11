public with sharing class LogEventTriggerService {
  private static final Integer MAX_RETRIES = 3;

  public static void save(List<LogEvent__e> events) {
    if (events.isEmpty())
      return;

    List<Log__c> logs = new List<Log__c>();
    for (LogEvent__e e : events)
      logs.add(fromEvent(e));

    List<Database.SaveResult> results = Database.insert(
      logs,
      false,
      AccessLevel.SYSTEM_MODE
    );
    EventBus.TriggerContext context = EventBus.TriggerContext.currentContext();
    handleResults(results, context == null ? 0 : context.retries);
  }

  @TestVisible
  private static void handleResults(
    List<Database.SaveResult> results,
    Integer retries
  ) {
    Integer failedCount = 0;
    Set<String> errorCodes = new Set<String>();
    for (Database.SaveResult result : results) {
      if (result.isSuccess())
        continue;

      failedCount++;

      for (Database.Error error : result.getErrors())
        errorCodes.add(String.valueOf(error.getStatusCode()));
    }

    if (failedCount == 0)
      return;

    if (errorCodes.contains('UNABLE_TO_LOCK_ROW') && retries < MAX_RETRIES)
      throw new EventBus.RetryableException(
        'Temporary lock while saving logs; retrying event batch.'
      );

    System.debug(
      LoggingLevel.ERROR,
      'Logger: ' +
        failedCount +
        ' log(s) not saved after ' +
        (retries + 1) +
        ' attempt(s). Error codes: ' +
        String.join(new List<String>(errorCodes), ', ')
    );
  }

  public static Log__c fromEvent(LogEvent__e e) {
    return new Log__c(
      EventUuid__c = e.EventUuid,
      Level__c = e.Level__c,
      Message__c = e.Message__c,
      Source__c = e.Source__c,
      ExceptionType__c = e.ExceptionType__c,
      StackTrace__c = e.StackTrace__c,
      TransactionId__c = e.TransactionId__c,
      UserId__c = e.UserId__c,
      OccurredAt__c = e.OccurredAt__c,
      Operation__c = e.Operation__c,
      RecordId__c = e.RecordId__c,
      Status__c = e.Status__c
    );
  }
}
