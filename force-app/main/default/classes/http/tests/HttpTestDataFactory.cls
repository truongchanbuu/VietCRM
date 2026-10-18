/** In-memory HTTP fixtures; no org data, Named Credential or remote endpoint needed. */
@IsTest
public with sharing class HttpTestDataFactory {
  public static ApiRequest request(String path) {
    ApiRequest value = new ApiRequest();
    value.endpoint = 'https://example.invalid' + path;
    value.requestId = path;
    return value;
  }
  public static List<ApiRequest> requests(Integer count) {
    List<ApiRequest> values = new List<ApiRequest>();
    for (Integer i = 0; i < count; i++) {
      values.add(request('/ok/' + i));
    }
    return values;
  }
  public static RestRequest inbound(String body, String media) {
    RestRequest value = new RestRequest();
    value.requestBody = body == null ? null : Blob.valueOf(body);
    if (media != null) {
      value.addHeader('Content-Type', media);
    }
    return value;
  }
  public class Mock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      if (request.getEndpoint().endsWith('/timeout')) {
        throw new System.CalloutException('secret endpoint credential timeout');
      }
      Integer status = request.getEndpoint().endsWith('/rate')
        ? 429
        : request.getEndpoint().endsWith('/unauthorized')
            ? 401
            : request.getEndpoint().endsWith('/server')
                ? 503
                : request.getEndpoint().endsWith('/redirect')
                    ? 302
                    : request.getEndpoint().endsWith('/empty') ? 204 : 200;
      HttpResponse result = new HttpResponse();
      result.setStatusCode(status);
      result.setHeader('Content-Type', 'application/json');
      result.setHeader('Retry-After', '30');
      if (status != 204) {
        result.setBody('{"ok":true}');
      }
      return result;
    }
  }
}
