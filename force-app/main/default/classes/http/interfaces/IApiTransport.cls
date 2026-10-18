/** Narrow callout boundary; implementations send one platform HTTP request. */
public interface IApiTransport {
  /**
   * Sends a single callout; bulk orchestration belongs to ApiHttpClient.
   * @param request Validated native request
   * @return Native HTTP response
   */
  HttpResponse send(HttpRequest request);
}
