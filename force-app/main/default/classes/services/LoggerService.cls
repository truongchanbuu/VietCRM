public class LoggerService {
  private static final List<LogEvent__e> LOG_EVENTS = new List<LogEvent__e>();
  private static final String TRANSACTION_ID = Request.getCurrent()
    .getRequestId();

  private String source;
  private LoggerService(String source) {
    this.source = source;
  }

  public void info(String msg, String operation, String recordID, Exception e) {
    LOG_EVENTS.add(createLog(LogLevel.INFO, msg, operation, recordID, e));
  }

  public void info(String msg) {
    info(msg, null, null, null);
  }

  public void error(
    String msg,
    String operation,
    String recordID,
    Exception e
  ) {
    LOG_EVENTS.add(createLog(LogLevel.ERROR, msg, operation, recordID, e));
  }

  public void error(String msg, String operation, String recordID) {
    error(msg, operation, recordID, null);
  }

  public void error(String msg, Exception e) {
    error(msg, null, null, e);
  }

  public static void flush() {
    if (LOG_EVENTS.isEmpty())
      return;
    List<LogEvent__e> pendingEvents = new List<LogEvent__e>(LOG_EVENTS);
    LOG_EVENTS.clear();

    List<Database.SaveResult> results = EventBus.publish(pendingEvents);
    handleFailedLogs(results);
  }

  // Factory
  public static LoggerService fromSource(String source) {
    return new LoggerService(source);
  }

  // Helper
  private LogEvent__e createLog(LogLevel level, String msg) {
    return createLog(level, msg, null, null, null);
  }

  private LogEvent__e createLog(LogLevel level, String msg, Exception e) {
    return createLog(level, msg, null, null, e);
  }

  private LogEvent__e createLog(
    LogLevel level,
    String msg,
    String operation,
    String recordID,
    Exception e
  ) {
    String logMsg = msg != null ? msg : e?.getMessage();
    String operationType = operation != null ? operation : 'UNSPECIFIED';

    return new LogEvent__e(
      Level__c = level.name(),
      ExceptionType__c = e?.getTypeName(),
      TransactionId__c = TRANSACTION_ID,
      Message__c = logMsg,
      OccurredAt__c = System.now(),
      StackTrace__c = e?.getStackTraceString(),
      Source__c = source,
      UserId__c = UserInfo.getUserId(),
      Operation__c = operationType,
      RecordId__c = recordID == null ? null : String.valueOf(recordID),
      Status__c = 'New'
    );
  }

  private static void handleFailedLogs(List<Database.SaveResult> results) {
    for (Integer i = 0; i < results.size(); ++i) {
      Database.SaveResult current = results[i];
      if (current.isSuccess())
        continue;
      for (Database.Error record : current.getErrors()) {
        System.debug(
          LoggingLevel.ERROR,
          'Logger failed at record, ' +
            record?.getStatusCode() +
            'with msg: ' +
            record?.getMessage()
        );
      }
    }
  }

  public enum LogLevel {
    INFO,
    WARN,
    DEBUG,
    ERROR
  }
}
