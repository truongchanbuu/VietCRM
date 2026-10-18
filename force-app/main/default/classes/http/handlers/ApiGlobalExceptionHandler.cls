/** Explicit REST boundary helper; Apex has no installable global exception interceptor. */
public with sharing class ApiGlobalExceptionHandler {
  /**
   * Maps typed safe application errors; sanitizes all unexpected exception details.
   * @param failure Caught exception; never pass raw details to the response
   * @param requestId Optional correlation identifier from trusted request handling
   * @return Safe error envelope
   */
  public static ApiResponse toResponse(Exception failure, String requestId) {
    if (failure instanceof ApiException) {
      ApiException known = (ApiException) failure;
      if (isPublicError(known)) {
        return ApiResponseFactory.failed(
          known.code,
          known.getMessage(),
          requestId
        );
      }
    }

    return ApiResponseFactory.internalError(requestId);
  }

  /**
   * Writes one safe error response at the outermost REST boundary.
   * @param target Explicit RestResponse
   * @param failure Caught exception
   * @param requestId Optional correlation identifier
   */
  public static void handle(
    RestResponse target,
    Exception failure,
    String requestId
  ) {
    Integer statusCode = 500;
    if (
      failure instanceof ApiException && isPublicError((ApiException) failure)
    ) {
      statusCode = ((ApiException) failure).statusCode;
    }

    ApiWriter.write(target, statusCode, toResponse(failure, requestId));
  }

  private static Boolean isPublicError(ApiException failure) {
    return failure.statusCode != null &&
      failure.statusCode >= 400 &&
      ApiWriter.supports(failure.statusCode) &&
      !String.isBlank(failure.code) &&
      !String.isBlank(failure.getMessage());
  }
}
