/** Enforces event create permission and submits a single bulk publish request. */
public virtual with sharing class LogEventPublisher {
  /**
   * Checks event create permission before submitting any events.
   * @param events Events whose UUIDs were initialized before publication.
   * @return Ordered acceptance outcomes; denied requests have no side effects.
   */
  public LogFlushResult publish(List<LogEvent__e> events) {
    LogFlushResult report = new LogFlushResult();
    if (events == null || events.isEmpty()) {
      return report;
    }
    // Platform events do not support field-level security; their create permission gates publication.
    if (
      !LogEvent__e.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .isCreateable()
    ) {
      return rejectAll(events, 'INSUFFICIENT_ACCESS');
    }
    List<Database.SaveResult> results;
    try {
      results = enqueue(events);
    } catch (DmlException failure) {
      return rejectAll(events, 'PUBLISH_EXCEPTION');
    }
    for (Integer i = 0; i < results.size(); i++) {
      List<String> codes = new List<String>();
      for (Database.Error failure : results[i].getErrors()) {
        codes.add(String.valueOf(failure.getStatusCode()));
      }
      report.addOutcome(events[i].EventUuid, results[i].isSuccess(), codes);
    }
    return report;
  }

  /**
   * Platform boundary, replaceable in tests to exercise partial rejection.
   * @param events Authorized events.
   * @return Salesforce's immediate acceptance results.
   */
  protected virtual List<Database.SaveResult> enqueue(
    List<LogEvent__e> events
  ) {
    return EventBus.publish(events);
  }

  private LogFlushResult rejectAll(List<LogEvent__e> events, String code) {
    LogFlushResult report = new LogFlushResult();
    for (LogEvent__e eventRecord : events) {
      report.addOutcome(eventRecord.EventUuid, false, new List<String>{ code });
    }
    return report;
  }
}
