/** Explicit formatters support additional text formats; JSON helpers remain the default. */
public with sharing class ApiRequestReader {
  /**
   * Retains the JSON-specific error code for existing endpoints.
   * @param request Explicit REST request
   * @return Untyped JSON data
   */
  public static Object readJson(RestRequest request) {
    return readJsonAs(request, null);
  }

  /**
   * Retains typed JSON parsing and forward-compatible DTO properties.
   * @param request Explicit REST request
   * @param dtoType Application DTO type
   * @return Deserialized JSON DTO
   */
  public static Object readAs(RestRequest request, System.Type dtoType) {
    requireType(dtoType);
    return readJsonAs(request, dtoType);
  }

  /**
   * Selects an application-owned decoder without modifying transport or JSON code.
   * @param request Explicit REST request
   * @param formatter Text formatter with media-type support rules
   * @return Untyped application data
   */
  public static Object read(RestRequest request, IApiBodyFormatter formatter) {
    return decode(request, null, formatter);
  }

  /**
   * Allows custom formatters to receive the intended application type.
   * @param request Explicit REST request
   * @param dtoType Application DTO type
   * @param formatter Text formatter
   * @return Deserialized application data
   */
  public static Object readAs(
    RestRequest request,
    System.Type dtoType,
    IApiBodyFormatter formatter
  ) {
    requireType(dtoType);
    return decode(request, dtoType, formatter);
  }

  private static Object readJsonAs(RestRequest request, System.Type dtoType) {
    try {
      return decode(request, dtoType, new ApiJsonFormatter());
    } catch (ApiException failure) {
      if (failure.code == 'INVALID_BODY') {
        throw ApiException.create(
          400,
          'INVALID_JSON',
          'Request body is not valid JSON for this endpoint.'
        );
      }
      throw failure;
    }
  }

  private static Object decode(
    RestRequest request,
    System.Type dtoType,
    IApiBodyFormatter formatter
  ) {
    if (formatter == null) {
      throw ApiException.create(
        500,
        'INVALID_FORMATTER',
        'Body formatter is required.'
      );
    }
    String body = bodyOf(request, formatter);

    try {
      return formatter.decode(body, dtoType);
    } catch (Exception failure) {
      throw invalidBody();
    }
  }

  private static String bodyOf(
    RestRequest request,
    IApiBodyFormatter formatter
  ) {
    if (request == null || request.requestBody == null) {
      throw ApiException.create(
        400,
        'INVALID_REQUEST',
        'Request body is required.'
      );
    }

    String contentType;
    for (String name : request.headers.keySet()) {
      if (name.equalsIgnoreCase('Content-Type')) {
        contentType = request.headers.get(name);
        break;
      }
    }
    if (!formatter.supports(contentType)) {
      throw ApiException.create(
        415,
        'UNSUPPORTED_MEDIA_TYPE',
        'Content-Type is not supported by the selected formatter.'
      );
    }

    String body;
    try {
      body = request.requestBody.toString();
    } catch (System.StringException failure) {
      throw invalidBody();
    }
    if (String.isBlank(body)) {
      throw ApiException.create(
        400,
        'INVALID_REQUEST',
        'Request body is required.'
      );
    }
    return body;
  }

  private static void requireType(System.Type dtoType) {
    if (dtoType == null) {
      throw ApiException.create(
        400,
        'INVALID_REQUEST',
        'DTO type is required.'
      );
    }
  }

  private static ApiException invalidBody() {
    return ApiException.create(
      400,
      'INVALID_BODY',
      'Request body is not valid for this endpoint.'
    );
  }
}
