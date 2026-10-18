/** Builds REST envelopes without writing headers or depending on RestContext. */
public with sharing class ApiResponseFactory {
  /**
   * Keeps the success envelope consistent for single values and bulk collections.
   * @param data JSON-serializable application result
   * @param requestId Optional correlation identifier
   * @return A fresh success envelope
   */
  public static ApiResponse success(Object data, String requestId) {
    ApiResponse response = new ApiResponse();
    response.success = true;
    response.data = data;
    response.requestId = requestId;
    return response;
  }

  /**
   * Application code must choose a message safe for public clients.
   * @param code Stable application error code
   * @param message Safe public message
   * @param requestId Optional correlation identifier
   * @return A fresh failure envelope with no success data
   * @throws ApiException when the public error contract is incomplete
   */
  public static ApiResponse failed(
    String code,
    String message,
    String requestId
  ) {
    if (String.isBlank(code) || String.isBlank(message)) {
      throw ApiException.create(
        500,
        'INVALID_RESPONSE',
        'A public error code and message are required.'
      );
    }

    ApiResponse response = new ApiResponse();
    response.success = false;
    response.error = new ApiError(code, message);
    response.requestId = requestId;
    return response;
  }

  /**
   * Centralizes the safe fallback so unexpected exception details cannot leak.
   * @param requestId Optional correlation identifier
   * @return A fresh generic internal-error envelope
   */
  public static ApiResponse internalError(String requestId) {
    return failed('INTERNAL_ERROR', 'An unexpected error occurred.', requestId);
  }
}
