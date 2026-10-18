/**
 * UTF-8 text representation boundary. Implementations must be pure: no callouts,
 * SOQL, DML or mutation of the input payload. HTTP error policy belongs to callers.
 */
public interface IApiBodyCodec {
  /** @return The output Content-Type, including UTF-8 charset when appropriate. */
  String getContentType();

  /**
   * Recognizes inbound content types, including optional parameters.
   * @param contentType HTTP Content-Type, possibly blank or mixed case
   * @return True when this codec can decode the supplied representation
   */
  Boolean supports(String contentType);

  /**
   * Encodes the supplied object into a UTF-8-compatible text body.
   * @param data Application data or an ApiResponse envelope
   * @return Non-null text; null data may encode to a representation of null
   */
  String encode(Object data);

  /**
   * Decodes text without imposing application validation or HTTP status policy.
   * @param body Text representation
   * @param targetType Optional type; null requests untyped decoding
   * @return Decoded application data; parsing errors may throw
   */
  Object decode(String body, System.Type targetType);
}
