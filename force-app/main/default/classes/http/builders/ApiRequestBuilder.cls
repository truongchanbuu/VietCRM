/** Validates outbound request metadata before the first callout in a batch. */
public with sharing class ApiRequestBuilder {
  private static final Set<String> METHODS = new Set<String>{
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS'
  };

  private static final Set<String> MANAGED_HEADERS = new Set<String>{
    'host',
    'content-length',
    'transfer-encoding',
    'connection'
  };

  /**
   * Builds a native request without network access or database work.
   * @param request Developer-owned endpoint, body, headers and query parameters
   * @return Validated HttpRequest
   * @throws ApiException for invalid configuration
   */
  public static HttpRequest build(ApiRequest request) {
    return build(request, null);
  }

  /**
   * Resolves the client's service and request path without mutating the DTO.
   * @param request HTTP operation and per-request configuration
   * @param baseEndpoint Client-owned base; null supports legacy absolute endpoints
   * @return Validated native request, without network or database work
   */
  public static HttpRequest build(ApiRequest request, String baseEndpoint) {
    if (request == null)
      throw invalid('Request is required.');

    String endpoint = resolveEndpoint(
      baseEndpoint,
      request.path,
      request.endpoint
    );
    String method = String.isBlank(request.method)
      ? ''
      : request.method.trim().toUpperCase();
    if (!METHODS.contains(method))
      throw invalid('Unsupported HTTP method.');
    if (
      request.timeoutMillis == null ||
      request.timeoutMillis < 1 ||
      request.timeoutMillis > 120000
    ) {
      throw invalid('Timeout must be between 1 and 120000 milliseconds.');
    }
    if (
      (method == 'GET' || method == 'HEAD') &&
      (request.body != null ||
      request.formatter != null)
    ) {
      throw invalid('GET and HEAD requests must not contain a body.');
    }

    HttpRequest result = new HttpRequest();
    result.setEndpoint(withQuery(endpoint, request.queryParameters));
    result.setMethod(method);
    result.setTimeout(request.timeoutMillis);
    applyHeaders(result, request.headers);
    applyBody(result, request);

    return result;
  }

  /**
   * Validates service configuration once when constructing a client.
   * @param baseEndpoint HTTPS or Named Credential base with an optional path prefix
   * @throws ApiException when the base contains an invalid endpoint, query or fragment
   */
  public static void validateBaseEndpoint(String baseEndpoint) {
    validateEndpoint(baseEndpoint);
    if (baseEndpoint.contains('?')) {
      throw invalid('Base endpoint must not contain query parameters.');
    }
  }

  /**
   * Appends the request path to the client-owned service prefix.
   * @param baseEndpoint Client-owned service, or null for legacy unbound clients
   * @param path Slash-prefixed service-relative path; null or empty addresses the base
   * @param endpoint Legacy full endpoint, only for unbound clients
   * @return Validated full endpoint without changing any request fields
   */
  private static String resolveEndpoint(
    String baseEndpoint,
    String path,
    String endpoint
  ) {
    if (baseEndpoint == null) {
      if (path != null) {
        throw invalid(
          'A client base endpoint is required when path is supplied.'
        );
      }
      validateEndpoint(endpoint);
      return endpoint;
    }

    validateBaseEndpoint(baseEndpoint);
    if (endpoint != null) {
      throw invalid(
        'Use request.path with a client that owns a base endpoint.'
      );
    }
    String relative = path == null ? '' : path;
    if (
      (!relative.startsWith('/') && relative != '') || relative.startsWith('//')
    ) {
      throw invalid('Request path must be empty or start with one slash.');
    }

    String resolved = baseEndpoint.replaceAll('/+$', '') + relative;
    validateEndpoint(resolved);
    return resolved;
  }

  private static void validateEndpoint(String endpoint) {
    if (
      String.isBlank(endpoint) ||
      Pattern.matches('(?s).*\\s.*', endpoint) ||
      endpoint.contains('#')
    ) {
      throw invalid('A valid HTTPS or Named Credential endpoint is required.');
    }
    Boolean named = Pattern.matches(
      '^callout:[A-Za-z_][A-Za-z0-9_]*(?:[/?].*)?$',
      endpoint
    );
    Boolean https = Pattern.matches('^https://[^/@?#]+(?:[/?].*)?$', endpoint);
    if (!named && !https) {
      throw invalid('Use HTTPS or a Named Credential endpoint.');
    }
  }

  private static String withQuery(
    String endpoint,
    Map<String, String> parameters
  ) {
    if (parameters == null || parameters.isEmpty())
      return endpoint;

    List<String> keys = new List<String>(parameters.keySet());
    keys.sort();
    List<String> pairs = new List<String>();
    for (String key : keys) {
      if (String.isBlank(key) || parameters.get(key) == null) {
        throw invalid('Query parameter names and values are required.');
      }
      pairs.add(
        EncodingUtil.urlEncode(key, 'UTF-8') +
          '=' +
          EncodingUtil.urlEncode(parameters.get(key), 'UTF-8')
      );
    }

    String separator = '?';
    if (endpoint.contains('?')) {
      separator = '&';
      if (endpoint.endsWith('?') || endpoint.endsWith('&'))
        separator = '';
    }

    return endpoint + separator + String.join(pairs, '&');
  }

  private static void applyHeaders(
    HttpRequest target,
    Map<String, String> headers
  ) {
    if (headers == null)
      return;

    Set<String> seen = new Set<String>();
    for (String name : headers.keySet()) {
      String value = headers.get(name);
      if (
        name == null ||
        !Pattern.matches('^[A-Za-z0-9!#$%&*+.^_`|~\\x27-]+$', name) ||
        value == null ||
        value.contains('\r') ||
        value.contains('\n') ||
        !seen.add(name.toLowerCase()) ||
        MANAGED_HEADERS.contains(name.toLowerCase())
      ) {
        throw invalid('Invalid, duplicate, or platform-managed HTTP header.');
      }

      target.setHeader(name, value);
    }
  }

  private static void applyBody(HttpRequest target, ApiRequest request) {
    if (request.formatter == null) {
      if (request.payload != null) {
        throw invalid('A formatter is required when payload is supplied.');
      }
      if (request.body != null)
        target.setBody(request.body);
      return;
    }
    if (request.body != null) {
      throw invalid('Choose raw body or formatter payload, not both.');
    }

    String contentType;
    if (request.headers != null) {
      for (String name : request.headers.keySet()) {
        if (name.equalsIgnoreCase('Content-Type')) {
          contentType = request.headers.get(name);
          break;
        }
      }
    }
    if (contentType == null)
      contentType = request.formatter.getContentType();
    if (
      String.isBlank(contentType) ||
      contentType.contains('\r') ||
      contentType.contains('\n') ||
      !request.formatter.supports(contentType)
    ) {
      throw invalid('Content-Type is not supported by the selected formatter.');
    }

    String body;
    try {
      body = request.formatter.encode(request.payload);
    } catch (Exception failure) {
      throw invalid('Request payload could not be encoded.');
    }
    if (body == null)
      throw invalid('Formatter must return a text body.');

    target.setHeader('Content-Type', contentType);
    target.setBody(body);
  }

  private static ApiException invalid(String message) {
    return ApiException.create(400, 'INVALID_REQUEST', message);
  }
}
