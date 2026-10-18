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
    return decode(
      new ApiJsonFormatter(),
      null,
      'INVALID_UPSTREAM_JSON',
      'Upstream response is not valid JSON.'
    );
  }

  /**
   * Decodes an upstream body with an explicitly supplied text formatter.
   * @param formatter Application-owned representation
   * @return Untyped data, or null for an empty response body
   */
  public Object read(IApiBodyFormatter formatter) {
    return decode(
      formatter,
      null,
      'INVALID_UPSTREAM_BODY',
      'Upstream response could not be decoded.'
    );
  }

  /**
   * Passes type information through to the selected decoder.
   * @param targetType Application DTO type
   * @param formatter Application-owned representation
   * @return Typed data, or null for an empty response body
   */
  public Object readAs(System.Type targetType, IApiBodyFormatter formatter) {
    if (targetType == null) {
      throw ApiException.create(
        500,
        'INVALID_FORMATTER',
        'A response type is required.'
      );
    }
    return decode(
      formatter,
      targetType,
      'INVALID_UPSTREAM_BODY',
      'Upstream response could not be decoded.'
    );
  }

  private Object decode(
    IApiBodyFormatter formatter,
    System.Type targetType,
    String errorCode,
    String message
  ) {
    if (formatter == null) {
      throw ApiException.create(
        500,
        'INVALID_FORMATTER',
        'Body formatter is required.'
      );
    }
    if (String.isBlank(body))
      return null;

    try {
      return formatter.decode(body, targetType);
    } catch (Exception failure) {
      throw ApiException.create(500, errorCode, message);
    }
  }
}
