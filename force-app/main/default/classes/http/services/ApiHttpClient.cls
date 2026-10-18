/**
 * Ordered, partial-outcome HTTP orchestration with preflight callout budgeting.
 * Performs no SOQL/DML, retries, queueing, or durable result storage.
 */
public with sharing class ApiHttpClient {
  private IApiTransport transport;

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
      prepared.add(ApiRequestBuilder.build(request));
    }

    List<ApiCalloutResult> results = new List<ApiCalloutResult>();
    for (Integer i = 0; i < prepared.size(); i++) {
      results.add(sendPrepared(prepared[i], requests[i].requestId));
    }

    return results;
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
