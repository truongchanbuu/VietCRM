/**
 * Ordered, partial-outcome HTTP orchestration with preflight callout budgeting.
 * Performs no SOQL/DML, retries, queueing, or durable result storage.
 */
public with sharing class ApiHttpClient {
  private IApiTransport transport;
  private String baseEndpoint;

  /** Uses the platform HTTP transport. */
  public ApiHttpClient() {
    this(new ApiHttpTransport());
  }

  /**
   * Injects an application transport without mutable global registration.
   * @param transport Native request/response adapter
   */
  public ApiHttpClient(IApiTransport transport) {
    if (transport == null) {
      throw ApiException.create(
        400,
        'INVALID_TRANSPORT',
        'Transport is required.'
      );
    }

    this.transport = transport;
  }

  /**
   * Binds the client to a service using the platform HTTP transport.
   * @param baseEndpoint HTTPS or Named Credential base, optionally with a path prefix
   */
  public ApiHttpClient(String baseEndpoint) {
    this(baseEndpoint, new ApiHttpTransport());
  }

  /**
   * Keeps service selection and execution policy on the client.
   * @param baseEndpoint HTTPS or Named Credential base without query or fragment
   * @param transport Native HTTP adapter
   */
  public ApiHttpClient(String baseEndpoint, IApiTransport transport) {
    this(transport);
    ApiRequestBuilder.validateBaseEndpoint(baseEndpoint);
    this.baseEndpoint = baseEndpoint;
  }

  /**
   * Sends a GET request through the same validated, budgeted client.
   * @param path Service-relative path, or full endpoint for an unbound client
   * @return Raw HTTP outcome; decoding remains explicit
   */
  public ApiCalloutResult get(String path) {
    return sendRequest('GET', path, null);
  }

  /**
   * Sends a POST request through the same validated, budgeted client.
   * @param path Service-relative path, or full endpoint for an unbound client
   * @param payload Application data serialized as JSON; null becomes JSON null
   * @return Raw HTTP outcome; decoding remains explicit
   */
  public ApiCalloutResult post(String path, Object payload) {
    return sendRequest('POST', path, payload);
  }

  /**
   * Sends a PUT request through the same validated, budgeted client.
   * @param path Service-relative path, or full endpoint for an unbound client
   * @param payload Application data serialized as JSON; null becomes JSON null
   * @return Raw HTTP outcome; decoding remains explicit
   */
  public ApiCalloutResult put(String path, Object payload) {
    return sendRequest('PUT', path, payload);
  }

  /**
   * Sends a PATCH request through the same validated, budgeted client.
   * @param path Service-relative path, or full endpoint for an unbound client
   * @param payload Application data serialized as JSON; null becomes JSON null
   * @return Raw HTTP outcome; decoding remains explicit
   */
  public ApiCalloutResult patch(String path, Object payload) {
    return sendRequest('PATCH', path, payload);
  }

  /**
   * Sends a DELETE request through the same validated, budgeted client.
   * @param path Service-relative path, or full endpoint for an unbound client
   * Apex reserves delete, so this shortcut uses deleteRequest.
   * @return Raw HTTP outcome; decoding remains explicit
   */
  public ApiCalloutResult deleteRequest(String path) {
    return sendRequest('DELETE', path, null);
  }

  /**
   * Single-request convenience API with identical bulk validation semantics.
   * @param request Developer-owned outbound request
   * @return Transport or HTTP outcome
   */
  public ApiCalloutResult send(ApiRequest request) {
    return sendAll(new List<ApiRequest>{ request })[0];
  }

  /**
   * Validates the whole batch before side effects, then preserves every outcome.
   * @param requests Ordered requests fitting the transaction callout/heap/time budgets
   * @return Exactly one result per request, in input order
   * @throws ApiException for invalid configuration or insufficient callout slots
   */
  public List<ApiCalloutResult> sendAll(List<ApiRequest> requests) {
    if (requests == null) {
      throw ApiException.create(
        400,
        'INVALID_REQUEST',
        'Requests are required.'
      );
    }

    Integer remaining = Limits.getLimitCallouts() - Limits.getCallouts();
    if (requests.size() > remaining) {
      throw ApiException.create(
        503,
        'CALLOUT_BUDGET_EXCEEDED',
        'Request batch exceeds remaining callout slots; use separate transactions.'
      );
    }

    List<HttpRequest> prepared = new List<HttpRequest>();
    for (ApiRequest request : requests) {
      prepared.add(ApiRequestBuilder.build(request, baseEndpoint));
    }

    List<ApiCalloutResult> results = new List<ApiCalloutResult>();
    for (Integer i = 0; i < prepared.size(); i++) {
      results.add(sendPrepared(prepared[i], requests[i].requestId));
    }

    return results;
  }

  private ApiCalloutResult sendRequest(
    String method,
    String endpoint,
    Object payload
  ) {
    ApiRequest request = new ApiRequest();
    if (baseEndpoint == null) {
      request.endpoint = endpoint;
    } else {
      request.path = endpoint;
    }
    request.method = method;
    if (method == 'POST' || method == 'PUT' || method == 'PATCH') {
      request.formatter = new ApiJsonFormatter();
      request.payload = payload;
    }

    return send(request);
  }

  private ApiCalloutResult sendPrepared(HttpRequest request, String requestId) {
    ApiCalloutResult result = new ApiCalloutResult();
    result.requestId = requestId;

    try {
      HttpResponse response = transport.send(request);
      if (response == null) {
        throw new System.CalloutException('Missing transport response');
      }

      result.statusCode = response.getStatusCode();
      result.body = response.getBody();
      for (String name : response.getHeaderKeys()) {
        result.headers.put(name.toLowerCase(), response.getHeader(name));
      }

      if (result.statusCode < 200 || result.statusCode >= 300) {
        result.error = new ApiError(
          'HTTP_ERROR',
          'Upstream service returned HTTP ' + result.statusCode + '.'
        );
      }
    } catch (System.CalloutException failure) {
      // Never leak endpoint credentials, upstream bodies or platform stack traces.
      result.error = new ApiError(
        'CALLOUT_FAILED',
        'Unable to complete HTTP callout.'
      );
    }

    return result;
  }
}
