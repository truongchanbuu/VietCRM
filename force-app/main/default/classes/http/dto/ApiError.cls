/** Safe error contract; contains no stack trace or underlying exception details. */
public with sharing class ApiError {
  public String code;
  public String message;

  /**
   * Creates a public error descriptor.
   * @param code Application-defined stable error code
   * @param message Safe message chosen by application code
   */
  public ApiError(String code, String message) {
    this.code = code;
    this.message = message;
  }
}
