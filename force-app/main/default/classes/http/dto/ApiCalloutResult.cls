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
      new ApiJsonCodec(),
      null,
      'INVALID_UPSTREAM_JSON',
      'Upstream response is not valid JSON.'
    );
  }

  /**
   * Decodes an upstream body with an explicitly supplied text codec.
   * @param codec Application-owned representation
   * @return Untyped data, or null for an empty response body
   */
  public Object read(IApiBodyCodec codec) {
    return decode(
      codec,
      null,
      'INVALID_UPSTREAM_BODY',
      'Upstream response could not be decoded.'
    );
  }

  /**
   * Passes type information through to the selected decoder.
   * @param targetType Application DTO type
   * @param codec Application-owned representation
   * @return Typed data, or null for an empty response body
   */
  public Object readAs(System.Type targetType, IApiBodyCodec codec) {
    if (targetType == null) {
      throw ApiException.create(
        500,
        'INVALID_CODEC',
        'A response type is required.'
      );
    }
    return decode(
      codec,
      targetType,
      'INVALID_UPSTREAM_BODY',
      'Upstream response could not be decoded.'
    );
  }

  private Object decode(
    IApiBodyCodec codec,
    System.Type targetType,
    String errorCode,
    String message
  ) {
    if (codec == null) {
      throw ApiException.create(
        500,
        'INVALID_CODEC',
        'Body codec is required.'
      );
    }
    if (String.isBlank(body))
      return null;

    try {
      return codec.decode(body, targetType);
    } catch (Exception failure) {
      throw ApiException.create(500, errorCode, message);
    }
  }
}
