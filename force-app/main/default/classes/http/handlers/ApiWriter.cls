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
    write(target, statusCode, payload, new ApiJsonCodec());
  }

  /**
   * Keeps HTTP/envelope policy independent of the selected text representation.
   * @param target Explicit RestResponse
   * @param statusCode Supported Apex REST status
   * @param payload Safe response envelope
   * @param codec Explicit text representation; no global format registry is used
   * @throws ApiException for invalid configuration or encoding failure
   */
  public static void write(
    RestResponse target,
    Integer statusCode,
    ApiResponse payload,
    IApiBodyCodec codec
  ) {
    if (
      target == null ||
      !supports(statusCode) ||
      payload == null ||
      payload.success == null ||
      codec == null
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

    String contentType = codec.getContentType();
    if (
      String.isBlank(contentType) ||
      contentType.contains('\r') ||
      contentType.contains('\n')
    ) {
      throw ApiException.create(
        500,
        'INVALID_RESPONSE',
        'Codec must provide a valid Content-Type.'
      );
    }

    Blob body;
    if (statusCode != 204 && statusCode != 304) {
      try {
        String encoded = codec.encode(payload);
        if (encoded == null) {
          throw ApiException.create(
            500,
            'INVALID_RESPONSE',
            'Codec must return a text body.'
          );
        }
        body = Blob.valueOf(encoded);
      } catch (Exception failure) {
        throw ApiException.create(
          500,
          'INVALID_RESPONSE',
          'Response could not be encoded.'
        );
      }
    }

    target.statusCode = statusCode;
    target.addHeader('Content-Type', contentType);
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
    write(target, statusCode, ApiResponseFactory.success(data, requestId));
  }

  /**
   * Writes 200 OK without a correlation identifier.
   * @param target Explicit RestResponse
   * @param data JSON-serializable application result
   */
  public static void success(RestResponse target, Object data) {
    success(target, data, null);
  }

  /**
   * Writes 200 OK with the common success envelope.
   * @param target Explicit RestResponse
   * @param data JSON-serializable application result
   * @param requestId Optional correlation identifier
   */
  public static void success(
    RestResponse target,
    Object data,
    String requestId
  ) {
    success(target, 200, data, requestId);
  }

  /**
   * Writes 201 Created without a correlation identifier.
   * @param target Explicit RestResponse
   * @param data JSON-serializable application result
   */
  public static void created(RestResponse target, Object data) {
    created(target, data, null);
  }

  /**
   * Writes 201 Created with the common success envelope.
   * @param target Explicit RestResponse
   * @param data JSON-serializable application result
   * @param requestId Optional correlation identifier
   */
  public static void created(
    RestResponse target,
    Object data,
    String requestId
  ) {
    success(target, 201, data, requestId);
  }

  /**
   * Writes 202 Accepted without a correlation identifier.
   * @param target Explicit RestResponse
   * @param data JSON-serializable application result
   */
  public static void accepted(RestResponse target, Object data) {
    accepted(target, data, null);
  }

  /**
   * Writes 202 Accepted with the common success envelope.
   * @param target Explicit RestResponse
   * @param data JSON-serializable application result
   * @param requestId Optional correlation identifier
   */
  public static void accepted(
    RestResponse target,
    Object data,
    String requestId
  ) {
    success(target, 202, data, requestId);
  }

  /**
   * Clears any previous body when the operation has no representation.
   * @param target Explicit RestResponse
   */
  public static void noContent(RestResponse target) {
    success(target, 204, null, null);
  }

  /**
   * Writes a custom public error without a correlation identifier.
   * @param target Explicit RestResponse
   * @param statusCode Supported Apex REST error status
   * @param error Explicitly safe public error
   */
  public static void failed(
    RestResponse target,
    Integer statusCode,
    ApiError error
  ) {
    failed(target, statusCode, error, null);
  }

  /**
   * Restricts named failure responses to supported error statuses and complete errors.
   * @param target Explicit RestResponse
   * @param statusCode Supported Apex REST error status
   * @param error Explicitly safe public error
   * @param requestId Optional correlation identifier
   * @throws ApiException for invalid error status or contract
   */
  public static void failed(
    RestResponse target,
    Integer statusCode,
    ApiError error,
    String requestId
  ) {
    if (
      statusCode == null ||
      statusCode < 400 ||
      !supports(statusCode) ||
      error == null
    ) {
      throw ApiException.create(
        500,
        'INVALID_RESPONSE',
        'A supported error status and public error are required.'
      );
    }

    write(
      target,
      statusCode,
      ApiResponseFactory.failed(error.code, error.message, requestId)
    );
  }

  /**
   * Writes 400 with a caller-chosen public message.
   * @param target Explicit RestResponse
   * @param message Safe public message
   */
  public static void badRequest(RestResponse target, String message) {
    badRequest(target, message, null);
  }

  /**
   * Writes 400 BAD_REQUEST and preserves correlation for the client.
   * @param target Explicit RestResponse
   * @param message Safe public message
   * @param requestId Optional correlation identifier
   */
  public static void badRequest(
    RestResponse target,
    String message,
    String requestId
  ) {
    failed(target, 400, new ApiError('BAD_REQUEST', message), requestId);
  }

  /**
   * Writes 401 with a caller-chosen public message.
   * @param target Explicit RestResponse
   * @param message Safe public message
   */
  public static void unauthorized(RestResponse target, String message) {
    unauthorized(target, message, null);
  }

  /**
   * Writes 401 UNAUTHORIZED and preserves correlation for the client.
   * @param target Explicit RestResponse
   * @param message Safe public message
   * @param requestId Optional correlation identifier
   */
  public static void unauthorized(
    RestResponse target,
    String message,
    String requestId
  ) {
    failed(target, 401, new ApiError('UNAUTHORIZED', message), requestId);
  }

  /**
   * Writes 403 with a caller-chosen public message.
   * @param target Explicit RestResponse
   * @param message Safe public message
   */
  public static void forbidden(RestResponse target, String message) {
    forbidden(target, message, null);
  }

  /**
   * Writes 403 FORBIDDEN and preserves correlation for the client.
   * @param target Explicit RestResponse
   * @param message Safe public message
   * @param requestId Optional correlation identifier
   */
  public static void forbidden(
    RestResponse target,
    String message,
    String requestId
  ) {
    failed(target, 403, new ApiError('FORBIDDEN', message), requestId);
  }

  /**
   * Writes 404 with a caller-chosen public message.
   * @param target Explicit RestResponse
   * @param message Safe public message
   */
  public static void notFound(RestResponse target, String message) {
    notFound(target, message, null);
  }

  /**
   * Writes 404 NOT_FOUND and preserves correlation for the client.
   * @param target Explicit RestResponse
   * @param message Safe public message
   * @param requestId Optional correlation identifier
   */
  public static void notFound(
    RestResponse target,
    String message,
    String requestId
  ) {
    failed(target, 404, new ApiError('NOT_FOUND', message), requestId);
  }

  /**
   * Writes 409 with a caller-chosen public message.
   * @param target Explicit RestResponse
   * @param message Safe public message
   */
  public static void conflict(RestResponse target, String message) {
    conflict(target, message, null);
  }

  /**
   * Writes 409 CONFLICT and preserves correlation for the client.
   * @param target Explicit RestResponse
   * @param message Safe public message
   * @param requestId Optional correlation identifier
   */
  public static void conflict(
    RestResponse target,
    String message,
    String requestId
  ) {
    failed(target, 409, new ApiError('CONFLICT', message), requestId);
  }

  /**
   * Writes 503 with a caller-chosen public message.
   * @param target Explicit RestResponse
   * @param message Safe public message
   */
  public static void serviceUnavailable(RestResponse target, String message) {
    serviceUnavailable(target, message, null);
  }

  /**
   * Writes 503 SERVICE_UNAVAILABLE and preserves correlation for the client.
   * @param target Explicit RestResponse
   * @param message Safe public message
   * @param requestId Optional correlation identifier
   */
  public static void serviceUnavailable(
    RestResponse target,
    String message,
    String requestId
  ) {
    failed(
      target,
      503,
      new ApiError('SERVICE_UNAVAILABLE', message),
      requestId
    );
  }

  /**
   * Writes a generic 500 without exposing an exception message.
   * @param target Explicit RestResponse
   */
  public static void internalError(RestResponse target) {
    internalError(target, null);
  }

  /**
   * Uses the same sanitized fallback as the exception handler.
   * @param target Explicit RestResponse
   * @param requestId Optional correlation identifier
   */
  public static void internalError(RestResponse target, String requestId) {
    write(target, 500, ApiResponseFactory.internalError(requestId));
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
