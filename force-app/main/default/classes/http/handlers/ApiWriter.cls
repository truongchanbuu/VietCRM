/** Writes a stable JSON envelope to an explicit Apex REST response. */
public with sharing class ApiWriter {
  private static final Set<Integer> STATUSES = new Set<Integer>{
    200,
    201,
    202,
    204,
    206,
    300,
    301,
    302,
    304,
    400,
    401,
    403,
    404,
    405,
    406,
    409,
    410,
    412,
    413,
    414,
    415,
    417,
    500,
    503
  };
  /**
   * Writes data or an error envelope; 204 and 304 have no body.
   * @param target Explicit RestResponse, normally RestContext.response
   * @param statusCode A status supported by Salesforce Apex REST
   * @param payload Safe JSON-serializable envelope
   * @throws ApiException for invalid target, status or envelope
   */
  public static void write(
    RestResponse target,
    Integer statusCode,
    ApiResponse payload
  ) {
    if (
      target == null ||
      !supports(statusCode) ||
      payload == null ||
      payload.success == null
    ) {
      throw ApiException.create(
        500,
        'INVALID_RESPONSE',
        'A valid REST response, status and envelope are required.'
      );
    }

    if (
      payload.success != (statusCode >= 200 && statusCode < 300) ||
      (payload.success && payload.error != null) ||
      (!payload.success && payload.error == null)
    ) {
      throw ApiException.create(
        500,
        'INVALID_RESPONSE',
        'REST status and envelope must agree.'
      );
    }

    Blob body;
    if (statusCode != 204 && statusCode != 304) {
      body = Blob.valueOf(JSON.serialize(payload));
    }

    target.statusCode = statusCode;
    target.addHeader('Content-Type', 'application/json; charset=UTF-8');
    target.addHeader('Cache-Control', 'no-store');
    target.responseBody = body;
  }

  /**
   * Writes a successful data envelope; use void Apex REST methods to avoid double serialization.
   * @param target Explicit RestResponse
   * @param statusCode Supported success status
   * @param data JSON-serializable data, including collections
   * @param requestId Optional caller-supplied correlation identifier
   */
  public static void success(
    RestResponse target,
    Integer statusCode,
    Object data,
    String requestId
  ) {
    ApiResponse payload = new ApiResponse();
    payload.success = true;
    payload.data = data;
    payload.requestId = requestId;

    write(target, statusCode, payload);
  }

  /**
   * Checks the platform-supported status set before changing a response.
   * @param statusCode Desired status
   * @return True when Apex REST supports the status
   */
  public static Boolean supports(Integer statusCode) {
    return statusCode != null && STATUSES.contains(statusCode);
  }
}
