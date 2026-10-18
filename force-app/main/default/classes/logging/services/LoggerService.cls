/** Buffers diagnostic events until the caller explicitly flushes the transaction. */
public with sharing class LoggerService {
  private static final List<LogEvent__e> LOG_EVENTS = new List<LogEvent__e>();
  @TestVisible
  private static LogEventPublisher publisher = new LogEventPublisher();
  private String source;

  private LoggerService(String source) {
    this.source = fit(source, LogEvent__e.Source__c);
  }

  /**
   * Creates a logger sharing the transaction buffer with all other sources.
   * @param source Caller-owned component name, truncated to the sample field size.
   * @return A source-specific logger.
   */
  public static LoggerService fromSource(String source) {
    return new LoggerService(source);
  }

  /**
   * Queues an informational event.
   * @param msg Caller-sanitized diagnostic message.
   */
  public void info(String msg) {
    info(msg, null, null, null);
  }

  /**
   * Queues an informational event with optional context.
   * @param msg Caller-sanitized diagnostic message.
   * @param operation Application operation name.
   * @param recordID Optional Salesforce record identifier.
   * @param e Optional exception whose details are safe for trusted log readers.
   */
  public void info(String msg, String operation, String recordID, Exception e) {
    queueEvent(LogLevel.INFO, msg, operation, recordID, e);
  }

  /**
   * Queues an error event with optional context.
   * @param msg Caller-sanitized diagnostic message.
   * @param operation Application operation name.
   * @param recordID Optional Salesforce record identifier.
   * @param e Optional exception whose details are safe for trusted log readers.
   */
  public void error(
    String msg,
    String operation,
    String recordID,
    Exception e
  ) {
    queueEvent(LogLevel.ERROR, msg, operation, recordID, e);
  }

  /**
   * Queues an error event without an exception.
   * @param msg Caller-sanitized diagnostic message.
   * @param operation Application operation name.
   * @param recordID Optional Salesforce record identifier.
   */
  public void error(String msg, String operation, String recordID) {
    error(msg, operation, recordID, null);
  }

  /**
   * Queues an error event using exception details when the message is null.
   * @param msg Caller-sanitized diagnostic message.
   * @param e Optional exception safe for trusted log readers.
   */
  public void error(String msg, Exception e) {
    error(msg, null, null, e);
  }

  /** Publishes pending entries without throwing for handled publication errors. */
  public static void flush() {
    LogFlushResult report = flushWithResult();
    if (report.rejectedCount > 0) {
      // Last-resort diagnostics must never recurse through this logger or expose payloads.
      System.debug(
        LoggingLevel.ERROR,
        'Logger rejected requests: ' + report.rejectedCount
      );
    }
  }

  /**
   * Publishes the current buffer and retains rejected entries for an explicit retry.
   * @return Ordered request outcomes, not an assurance of final delivery.
   */
  public static LogFlushResult flushWithResult() {
    if (LOG_EVENTS.isEmpty()) {
      return new LogFlushResult();
    }
    List<LogEvent__e> pending = new List<LogEvent__e>(LOG_EVENTS);
    LogFlushResult report = publisher.publish(pending);
    LOG_EVENTS.clear();
    for (Integer i = 0; i < pending.size(); i++) {
      if (!report.outcomes[i].accepted) {
        LOG_EVENTS.add(pending[i]);
      }
    }
    return report;
  }

  private void queueEvent(
    LogLevel level,
    String msg,
    String operation,
    String recordID,
    Exception e
  ) {
    String validatedId;
    if (recordID != null) {
      try {
        validatedId = String.valueOf(Id.valueOf(recordID));
      } catch (StringException failure) {
        throw new LoggerException('Record identifier must be a Salesforce Id.');
      }
    }
    LogEvent__e eventRecord = (LogEvent__e) LogEvent__e.SObjectType.newSObject(
      null,
      true
    );
    eventRecord.Level__c = level.name();
    eventRecord.Message__c = fit(
      msg ?? e?.getMessage(),
      LogEvent__e.Message__c
    );
    eventRecord.Source__c = source;
    eventRecord.Operation__c = fit(
      operation ?? 'UNSPECIFIED',
      LogEvent__e.Operation__c
    );
    eventRecord.RecordId__c = validatedId;
    eventRecord.ExceptionType__c = fit(
      e?.getTypeName(),
      LogEvent__e.ExceptionType__c
    );
    eventRecord.StackTrace__c = fit(
      e?.getStackTraceString(),
      LogEvent__e.StackTrace__c
    );
    eventRecord.TransactionId__c = Request.getCurrent().getRequestId();
    eventRecord.UserId__c = UserInfo.getUserId();
    eventRecord.OccurredAt__c = System.now();
    eventRecord.Status__c = 'New';
    LOG_EVENTS.add(eventRecord);
  }

  private static String fit(String value, Schema.SObjectField field) {
    return value == null ? null : value.left(field.getDescribe().getLength());
  }

  /** Severity vocabulary; adapt together with the stored log picklist. */
  public enum LogLevel {
    INFO,
    WARN,
    DEBUG,
    ERROR
  }
}
