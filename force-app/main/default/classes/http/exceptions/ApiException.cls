/** Explicit application error whose code and message are safe for REST clients. */
public with sharing class ApiException extends Exception {
  public Integer statusCode;
  public String code;

  /**
   * Builds a typed application exception. Unexpected exceptions are sanitized separately.
   * @param statusCode Supported Apex REST error status (400-599)
   * @param code Stable application error code
   * @param message Safe public message, never raw upstream/credential details
   * @return An exception ready to throw
   */
  public static ApiException create(
    Integer statusCode,
    String code,
    String message
  ) {
    ApiException failure = new ApiException(message);
    failure.statusCode = statusCode;
    failure.code = code;
    return failure;
  }
}
