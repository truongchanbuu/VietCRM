/** JSON-only inbound parsing; application validation remains with the endpoint. */
public with sharing class ApiRequestReader {
  /**
   * Parses an inbound JSON request without database access.
   * @param request Explicit REST request
   * @return Untyped JSON data
   * @throws ApiException for missing/invalid JSON or unsupported media type
   */
  public static Object readJson(RestRequest request) {
    String body = bodyOf(request);

    try {
      return JSON.deserializeUntyped(body);
    } catch (System.JSONException failure) {
      throw invalidJson();
    }
  }

  /**
   * Parses a typed DTO, allowing additional JSON properties for API evolution.
   * @param request Explicit REST request
   * @param dtoType Application DTO type
   * @return Deserialized DTO; endpoints must validate required fields and null data
   * @throws ApiException for invalid configuration or invalid JSON
   */
  public static Object readAs(RestRequest request, System.Type dtoType) {
    if (dtoType == null) {
      throw ApiException.create(
        400,
        'INVALID_REQUEST',
        'DTO type is required.'
      );
    }
    String body = bodyOf(request);

    try {
      return JSON.deserialize(body, dtoType);
    } catch (System.JSONException failure) {
      throw invalidJson();
    }
  }

  private static String bodyOf(RestRequest request) {
    if (request == null || request.requestBody == null) {
      throw ApiException.create(
        400,
        'INVALID_REQUEST',
        'JSON request body is required.'
      );
    }

    String contentType;
    for (String name : request.headers.keySet()) {
      if (name.equalsIgnoreCase('Content-Type')) {
        contentType = request.headers.get(name);
        break;
      }
    }
    String media = contentType == null
      ? ''
      : contentType.substringBefore(';').trim().toLowerCase();
    if (
      media != 'application/json' &&
      !Pattern.matches('^application/[a-z0-9!#$&^_.+-]+\\+json$', media)
    ) {
      throw ApiException.create(
        415,
        'UNSUPPORTED_MEDIA_TYPE',
        'Content-Type must be application/json or application/*+json.'
      );
    }

    String body;

    try {
      body = request.requestBody.toString();
    } catch (System.StringException failure) {
      throw invalidJson();
    }
    if (String.isBlank(body)) {
      throw ApiException.create(
        400,
        'INVALID_REQUEST',
        'JSON request body is required.'
      );
    }

    return body;
  }

  private static ApiException invalidJson() {
    return ApiException.create(
      400,
      'INVALID_JSON',
      'Request body is not valid JSON for this endpoint.'
    );
  }
}
