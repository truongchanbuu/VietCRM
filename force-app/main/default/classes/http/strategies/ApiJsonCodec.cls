/** Default JSON representation, shared by optional outbound and REST adapters. */
public with sharing class ApiJsonCodec implements IApiBodyCodec {
  /** @return The default JSON UTF-8 Content-Type. */
  public String getContentType() {
    return 'application/json; charset=UTF-8';
  }

  /**
   * Accepts vendor JSON media types without requiring a registry entry.
   * @param contentType HTTP Content-Type, including optional charset
   * @return True for application/json or application/*+json
   */
  public Boolean supports(String contentType) {
    if (String.isBlank(contentType))
      return false;

    String media = contentType.substringBefore(';').trim().toLowerCase();
    return media == 'application/json' ||
      Pattern.matches('^application/[a-z0-9!#$&^_.+-]+\\+json$', media);
  }

  /**
   * Uses the platform serializer to preserve escaping and collection semantics.
   * @param data Application data or response envelope
   * @return JSON text, including a JSON null for null data
   */
  public String encode(Object data) {
    return JSON.serialize(data);
  }

  /**
   * Leaves parsing exceptions to the inbound/outbound boundary for safe mapping.
   * @param body JSON text
   * @param targetType Optional Apex DTO type
   * @return Typed or untyped JSON data
   */
  public Object decode(String body, System.Type targetType) {
    if (targetType == null)
      return JSON.deserializeUntyped(body);

    return JSON.deserialize(body, targetType);
  }
}
