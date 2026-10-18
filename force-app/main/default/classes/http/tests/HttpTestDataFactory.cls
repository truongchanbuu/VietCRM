/** In-memory HTTP fixtures; no org data, Named Credential or remote endpoint needed. */
@IsTest
public with sharing class HttpTestDataFactory {
  public static ApiRequest request(String path) {
    ApiRequest request = new ApiRequest();
    request.endpoint = 'https://example.invalid' + path;
    request.requestId = path;

    return request;
  }

  public static List<ApiRequest> requests(Integer count) {
    List<ApiRequest> requests = new List<ApiRequest>();
    for (Integer i = 0; i < count; i++) {
      requests.add(request('/ok/' + i));
    }

    return requests;
  }

  public static RestRequest inbound(String body, String media) {
    RestRequest request = new RestRequest();
    request.requestBody = body == null ? null : Blob.valueOf(body);
    if (media != null) {
      request.addHeader('Content-Type', media);
    }

    return request;
  }

  public class Mock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      if (request.getEndpoint().endsWith('/timeout')) {
        throw new System.CalloutException('secret endpoint credential timeout');
      }

      Integer status = 200;
      if (request.getEndpoint().endsWith('/rate')) {
        status = 429;
      } else if (request.getEndpoint().endsWith('/unauthorized')) {
        status = 401;
      } else if (request.getEndpoint().endsWith('/server')) {
        status = 503;
      } else if (request.getEndpoint().endsWith('/redirect')) {
        status = 302;
      } else if (request.getEndpoint().endsWith('/empty')) {
        status = 204;
      }

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
