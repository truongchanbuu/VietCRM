/** Common verb shortcuts use the same transport and preflight policies. */
@IsTest
private class ApiHttpShortcutsTest {
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
  static void commonVerbsBuildAndSendWithoutManualRequests() {
    RecordingTransport transport = new RecordingTransport();
    ApiHttpClient client = new ApiHttpClient(transport);
    String endpoint = 'callout:Partner_API/items';
    Object payload = new Map<String, Object>{ 'reference' => 'item-1' };
    Test.startTest();
    List<ApiCalloutResult> results = new List<ApiCalloutResult>{
      client.get(endpoint),
      client.post(endpoint, payload),
      client.put(endpoint, payload),
      client.patch(endpoint, payload),
      client.deleteRequest(endpoint)
    };
    Test.stopTest();

    List<String> verbs = new List<String>{
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE'
    };
    Assert.areEqual(verbs.size(), transport.requests.size());
    for (Integer index = 0; index < verbs.size(); index++) {
      HttpRequest request = transport.requests[index];
      Assert.areEqual(verbs[index], request.getMethod());
      Assert.areEqual(endpoint, request.getEndpoint());
      Assert.isTrue(results[index].isSuccess());
      if (index == 0 || index == verbs.size() - 1) {
        Assert.isTrue(String.isBlank(request.getBody()));
      } else {
        Assert.areEqual(
          'application/json; charset=UTF-8',
          request.getHeader('Content-Type')
        );
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(
          request.getBody()
        );
        Assert.areEqual('item-1', data.get('reference'));
      }
    }
  }

  @IsTest
  static void bulkPayloadConsumesOneNativeCalloutAndNoDatabaseWork() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());
    List<String> items = new List<String>();
    for (Integer index = 0; index < 251; index++)
      items.add('item-' + index);
    Test.startTest();
    Integer queries = Limits.getQueries();
    Integer dml = Limits.getDmlStatements();
    ApiCalloutResult result = new ApiHttpClient()
      .post('https://example.invalid/bulk', items);
    Assert.areEqual(1, Limits.getCallouts());
    Assert.areEqual(queries, Limits.getQueries());
    Assert.areEqual(dml, Limits.getDmlStatements());
    Test.stopTest();
    Assert.isTrue(result.isSuccess());
  }

  @IsTest
  static void nullPayloadIsAnExplicitJsonNull() {
    RecordingTransport transport = new RecordingTransport();
    Test.startTest();
    ApiCalloutResult result = new ApiHttpClient(transport)
      .post('https://example.invalid/items', null);
    Test.stopTest();
    Assert.areEqual('null', transport.requests[0].getBody());
    Assert.isTrue(result.isSuccess());
  }

  @IsTest
  static void invalidEndpointRejectsBeforeTransport() {
    RecordingTransport transport = new RecordingTransport();
    try {
      new ApiHttpClient(transport).get('http://example.invalid');
      Assert.fail('Expected invalid endpoint');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_REQUEST', failure.code);
    }
    Assert.areEqual(0, transport.requests.size());
  }

  @IsTest
  static void shortcutsRetainHttpAndTransportFailureOutcomes() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());
    Test.startTest();
    ApiHttpClient client = new ApiHttpClient();
    ApiCalloutResult httpFailure = client.get('https://example.invalid/rate');
    ApiCalloutResult transportFailure = client.get(
      'https://example.invalid/timeout'
    );
    Test.stopTest();
    Assert.areEqual(429, httpFailure.statusCode);
    Assert.areEqual('HTTP_ERROR', httpFailure.error.code);
    Assert.areEqual('CALLOUT_FAILED', transportFailure.error.code);
    Assert.isFalse(transportFailure.error.message.contains('secret'));
  }

  @IsTest
  static void shortcutRejectsAnExhaustedNativeCalloutBudget() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());
    Test.startTest();
    new ApiHttpClient()
      .sendAll(HttpTestDataFactory.requests(Limits.getLimitCallouts()));
    try {
      new ApiHttpClient().deleteRequest('https://example.invalid/items');
      Assert.fail('Expected exhausted budget');
    } catch (ApiException failure) {
      Assert.areEqual('CALLOUT_BUDGET_EXCEEDED', failure.code);
    }
    Assert.areEqual(Limits.getLimitCallouts(), Limits.getCallouts());
    Test.stopTest();
  }
}
