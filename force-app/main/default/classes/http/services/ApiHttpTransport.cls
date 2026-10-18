/** Default transport using Salesforce HTTP and Named Credential resolution. */
public with sharing class ApiHttpTransport implements IApiTransport {
  /**
   * Delegates a callout to the platform, honoring HttpCalloutMock in tests.
   * @param request Validated native request
   * @return Native HTTP response
   */
  public HttpResponse send(HttpRequest request) {
    return new Http().send(request);
  }
}
