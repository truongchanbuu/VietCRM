/** Describes publish-request acceptance, not final event delivery or persistence. */
public with sharing class LogFlushResult {
  public Integer acceptedCount = 0;
  public Integer rejectedCount = 0;
  public List<Outcome> outcomes = new List<Outcome>();

  /**
   * Records an outcome in the same order as the submitted events.
   * @param eventUuid Event identity, preserved for an explicit retry.
   * @param accepted Whether Salesforce accepted the publish request.
   * @param errorCodes Sanitized status codes without message payloads.
   */
  public void addOutcome(
    String eventUuid,
    Boolean accepted,
    List<String> errorCodes
  ) {
    Outcome outcome = new Outcome();
    outcome.eventUuid = eventUuid;
    outcome.accepted = accepted;
    outcome.errorCodes = errorCodes;
    outcomes.add(outcome);
    if (accepted) {
      acceptedCount++;
    } else {
      rejectedCount++;
    }
  }

  /** One request outcome; contains no log message or exception details. */
  public with sharing class Outcome {
    public String eventUuid;
    public Boolean accepted;
    public List<String> errorCodes;
  }
}
