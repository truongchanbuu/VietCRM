/** Service configuration belongs to the client; operation data stays on the request. */
@IsTest
private class ApiServiceClientTest {
  private class RecordingTransport implements IApiTransport {
    List<HttpRequest> requests = new List<HttpRequest>();

    public HttpResponse send(HttpRequest request) {
      requests.add(request);
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody('{"ready":true}');
      return response;
    }
  }

  @IsTest
  static void commonOperationsUseTheClientService() {
    RecordingTransport transport = new RecordingTransport();
    ApiHttpClient client = new ApiHttpClient('callout:CRM_API', transport);
    Object account = new Map<String, Object>{ 'name' => 'Example' };
    Test.startTest();
    List<ApiCalloutResult> results = new List<ApiCalloutResult>{
      client.get('/v1/accounts'),
      client.post('/v1/accounts', account),
      client.put('/v1/accounts/123', account),
      client.patch('/v1/accounts/123', account),
      client.deleteRequest('/v1/accounts/123')
    };
    Test.stopTest();

    List<String> methods = new List<String>{
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE'
    };
    Assert.areEqual(methods.size(), transport.requests.size());
    for (Integer index = 0; index < methods.size(); index++) {
      HttpRequest request = transport.requests[index];
      Assert.areEqual(methods[index], request.getMethod());
      Assert.isTrue(
        request.getEndpoint().startsWith('callout:CRM_API/v1/accounts')
      );
      Assert.isTrue(results[index].isSuccess());
    }
    Assert.areEqual(
      'callout:CRM_API/v1/accounts/123',
      transport.requests[4].getEndpoint()
    );
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      transport.requests[1].getBody()
    );
    Assert.areEqual('Example', body.get('name'));
  }

  @IsTest
  static void requestOwnsPathPayloadHeadersQueryAndCorrelation() {
    RecordingTransport transport = new RecordingTransport();
    ApiHttpClient client = new ApiHttpClient(
      'https://example.invalid/crm/',
      transport
    );
    ApiRequest request = new ApiRequest();
    request.path = '/v1/accounts';
    request.method = 'POST';
    request.payload = new Map<String, Object>{ 'name' => 'Example' };
    request.formatter = new ApiJsonFormatter();
    request.headers.put('X-Correlation', 'request-1');
    request.queryParameters.put('label', 'active & ready');
    request.timeoutMillis = 5000;
    request.requestId = 'request-1';
    Test.startTest();
    ApiCalloutResult result = client.send(request);
    Test.stopTest();

    HttpRequest sent = transport.requests[0];
    Assert.areEqual(
      'https://example.invalid/crm/v1/accounts?label=active+%26+ready',
      sent.getEndpoint()
    );
    Assert.areEqual('request-1', sent.getHeader('X-Correlation'));
    Assert.areEqual(
      'application/json; charset=UTF-8',
      sent.getHeader('Content-Type')
    );
    Assert.areEqual('request-1', result.requestId);
    Assert.areEqual('/v1/accounts', request.path);
    Assert.isNull(request.endpoint);
  }

  @IsTest
  static void servicePrefixAndRootPathsJoinConsistently() {
    RecordingTransport transport = new RecordingTransport();
    ApiHttpClient client = new ApiHttpClient('callout:CRM_API/api/', transport);
    client.get('/v1/accounts');
    client.get('');
    client.get('/');
    client.send(new ApiRequest());
    List<String> expected = new List<String>{
      'callout:CRM_API/api/v1/accounts',
      'callout:CRM_API/api',
      'callout:CRM_API/api/',
      'callout:CRM_API/api'
    };
    Assert.areEqual(expected.size(), transport.requests.size());
    for (Integer index = 0; index < expected.size(); index++) {
      Assert.areEqual(expected[index], transport.requests[index].getEndpoint());
    }
  }

  @IsTest
  static void oneRequestCanBeReusedWithDifferentServiceClients() {
    RecordingTransport transport = new RecordingTransport();
    ApiRequest request = new ApiRequest();
    request.path = '/health';
    new ApiHttpClient('callout:CRM_API', transport).send(request);
    new ApiHttpClient('callout:Other_API', transport).send(request);
    Assert.areEqual(
      'callout:CRM_API/health',
      transport.requests[0].getEndpoint()
    );
    Assert.areEqual(
      'callout:Other_API/health',
      transport.requests[1].getEndpoint()
    );
    Assert.areEqual('/health', request.path);
    Assert.isNull(request.endpoint);
  }

  @IsTest
  static void invalidBatchPathRejectsBeforeAnyCallout() {
    RecordingTransport transport = new RecordingTransport();
    ApiRequest valid = new ApiRequest();
    valid.path = '/health';
    ApiRequest invalid = new ApiRequest();
    invalid.path = 'missing-slash';
    try {
      new ApiHttpClient('callout:CRM_API', transport)
        .sendAll(new List<ApiRequest>{ valid, invalid });
      Assert.fail('Expected invalid path');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_REQUEST', failure.code);
    }
    Assert.areEqual(0, transport.requests.size());
  }

  @IsTest
  static void invalidBaseConfigurationIsRejected() {
    for (
      String base : new List<String>{
        null,
        '',
        'http://example.invalid',
        'callout:CRM_API?tenant=1'
      }
    ) {
      try {
        new ApiHttpClient(base);
        Assert.fail('Expected invalid service base');
      } catch (ApiException failure) {
        Assert.areEqual('INVALID_REQUEST', failure.code);
      }
    }
    try {
      new ApiHttpClient('callout:CRM_API', null);
      Assert.fail('Expected missing transport');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_TRANSPORT', failure.code);
    }
  }

  @IsTest
  static void ambiguousOrUnboundTargetsAreRejected() {
    ApiRequest request = new ApiRequest();
    request.endpoint = 'https://example.invalid/accounts';
    assertInvalidTarget(
      new ApiHttpClient('callout:CRM_API', new RecordingTransport()),
      request
    );
    request.path = '/accounts';
    assertInvalidTarget(
      new ApiHttpClient('callout:CRM_API', new RecordingTransport()),
      request
    );
    request.endpoint = null;
    assertInvalidTarget(new ApiHttpClient(new RecordingTransport()), request);
    request.path = '//other.invalid/accounts';
    assertInvalidTarget(
      new ApiHttpClient('callout:CRM_API', new RecordingTransport()),
      request
    );
    request.path = 'https://other.invalid/accounts';
    assertInvalidTarget(
      new ApiHttpClient('callout:CRM_API', new RecordingTransport()),
      request
    );
  }

  private static void assertInvalidTarget(
    ApiHttpClient client,
    ApiRequest request
  ) {
    try {
      client.send(request);
      Assert.fail('Expected invalid target configuration');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_REQUEST', failure.code);
    }
  }

  @IsTest
  static void configuredClientUsesNativeTransportWithOneCallout() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());
    Test.startTest();
    ApiCalloutResult result = new ApiHttpClient('https://example.invalid')
      .get('/health');
    Assert.areEqual(1, Limits.getCallouts());
    Test.stopTest();
    Assert.isTrue(result.isSuccess());
  }
}
