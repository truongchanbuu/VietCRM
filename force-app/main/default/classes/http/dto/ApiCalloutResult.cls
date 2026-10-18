/** One outbound outcome, aligned with the original request's position. */
public with sharing class ApiCalloutResult {
  public String requestId;
  public Integer statusCode;
  public String body;
  public Map<String, String> headers = new Map<String, String>();
  public ApiError error;

  /** @return True only for a transport success with a 2xx HTTP status. */
  public Boolean isSuccess() {
    return error == null &&
      statusCode != null &&
      statusCode >= 200 &&
      statusCode < 300;
  }

  /**
   * Parses a JSON response only when the caller needs it.
   * @return Untyped JSON data, or null for an empty body
   * @throws ApiException for malformed JSON
   */
  public Object readJson() {
    if (String.isBlank(body))
      return null;

    try {
      return JSON.deserializeUntyped(body);
    } catch (System.JSONException e) {
      throw ApiException.create(
        500,
        'INVALID_UPSTREAM_JSON',
        'Upstream response is not valid JSON.'
      );
    }
  }
}
