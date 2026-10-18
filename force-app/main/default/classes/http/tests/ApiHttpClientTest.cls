/** Native mocks exercise callout accounting, ordered partial outcomes and preflight. */
@IsTest
private class ApiHttpClientTest {
  private class NullTransport implements IApiTransport {
    public HttpResponse send(HttpRequest request) {
      return null;
    }
  }

  private class BulkMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      Assert.areEqual(
        251,
        ((List<Object>) JSON.deserializeUntyped(request.getBody())).size(),
        'One remote bulk request contains the entire collection'
      );
      HttpResponse response = new HttpResponse();
      response.setStatusCode(202);
      response.setBody('{"accepted":251}');
      return response;
    }
  }

  @IsTest
  static void sends251RecordsInOneBulkRequest() {
    List<Integer> records = new List<Integer>();
    for (Integer i = 0; i < 251; i++) {
      records.add(i);
    }
    ApiRequest request = HttpTestDataFactory.request('/bulk');
    request.method = 'POST';
    request.body = JSON.serialize(records);
    request.headers.put('Content-Type', 'application/json');
    Test.setMock(HttpCalloutMock.class, new BulkMock());

    Test.startTest();
    ApiCalloutResult result = new ApiHttpClient().send(request);
    Assert.areEqual(
      1,
      Limits.getCallouts(),
      'Use one bulk API call, not 251 callouts'
    );
    Test.stopTest();

    Assert.isTrue(result.isSuccess(), '202 accepted is successful');
    Assert.areEqual(
      251,
      ((Map<String, Object>) result.readJson()).get('accepted'),
      'Remote acknowledgment'
    );
  }

  @IsTest
  static void sendsFullAvailableBudget() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());
    List<ApiRequest> requests = HttpTestDataFactory.requests(100);

    Test.startTest();
    Integer queries = Limits.getQueries();
    Integer dml = Limits.getDmlStatements();
    List<ApiCalloutResult> results = new ApiHttpClient().sendAll(requests);
    Assert.areEqual(
      100,
      Limits.getCallouts(),
      'Use exactly the available callout count'
    );
    Assert.areEqual(queries, Limits.getQueries(), 'HTTP toolkit uses no SOQL');
    Assert.areEqual(dml, Limits.getDmlStatements(), 'HTTP toolkit uses no DML');
    Test.stopTest();

    Assert.areEqual(100, results.size(), 'One outcome per request');
    for (Integer i = 0; i < results.size(); i++) {
      Assert.isTrue(results[i].isSuccess(), 'Mock result must succeed');
      Assert.areEqual(
        requests[i].requestId,
        results[i].requestId,
        'Keep original ordering'
      );
    }
  }

  @IsTest
  static void preservesMixedOutcomesWithoutRetry() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());
    List<ApiRequest> requests = new List<ApiRequest>();
    for (
      String path : new List<String>{
        '/ok',
        '/rate',
        '/timeout',
        '/server',
        '/unauthorized',
        '/redirect',
        '/empty',
        '/ok'
      }
    ) {
      requests.add(HttpTestDataFactory.request(path));
    }

    Test.startTest();
    List<ApiCalloutResult> results = new ApiHttpClient().sendAll(requests);
    Assert.areEqual(
      requests.size(),
      Limits.getCallouts(),
      'No automatic retries'
    );
    Test.stopTest();

    Assert.isTrue(results[0].isSuccess(), 'First response succeeds');
    Assert.areEqual(429, results[1].statusCode, 'Preserve upstream rate limit');
    Assert.areEqual(
      '30',
      results[1].headers.get('retry-after'),
      'Headers use lowercase keys'
    );
    Assert.areEqual(
      'CALLOUT_FAILED',
      results[2].error.code,
      'Transport failure is distinct'
    );
    Assert.isFalse(
      JSON.serialize(results[2]).contains('secret'),
      'No raw exception details'
    );
    Assert.areEqual(503, results[3].statusCode, 'Preserve upstream 5xx');
    Assert.areEqual(401, results[4].statusCode, 'Preserve upstream 4xx');
    Assert.isFalse(
      results[5].isSuccess(),
      'Do not classify redirects as success'
    );
    Assert.isTrue(results[6].isSuccess(), '204 succeeds');
    Assert.isNull(results[6].readJson(), '204 needs no JSON body');
    Assert.isTrue(
      results[7].isSuccess(),
      'A failed request must not discard subsequent work'
    );
    Assert.areEqual(
      true,
      ((Map<String, Object>) results[0].readJson()).get('ok'),
      'Lazy JSON parsing'
    );
  }

  @IsTest
  static void rejects251RequestsBeforeSending() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());

    Test.startTest();
    try {
      new ApiHttpClient().sendAll(HttpTestDataFactory.requests(251));
      Assert.fail('251 separate callouts cannot fit in one transaction');
    } catch (ApiException failure) {
      Assert.areEqual(
        'CALLOUT_BUDGET_EXCEEDED',
        failure.code,
        'Use transaction-sized chunks'
      );
    }
    Assert.areEqual(0, Limits.getCallouts(), 'Reject before any side effects');
    Test.stopTest();
  }

  @IsTest
  static void considersAlreadyConsumedCallouts() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());

    Test.startTest();
    new ApiHttpClient().send(HttpTestDataFactory.request('/ok'));
    try {
      new ApiHttpClient().sendAll(HttpTestDataFactory.requests(100));
      Assert.fail('Only 99 slots remain');
    } catch (ApiException failure) {
      Assert.areEqual(
        'CALLOUT_BUDGET_EXCEEDED',
        failure.code,
        'Count applies across client instances'
      );
    }
    Assert.areEqual(1, Limits.getCallouts(), 'No second batch started');
    Test.stopTest();
  }

  @IsTest
  static void validatesWholeBatchBeforeSending() {
    Test.setMock(HttpCalloutMock.class, new HttpTestDataFactory.Mock());
    List<ApiRequest> requests = HttpTestDataFactory.requests(2);
    requests[1].method = 'BAD';

    Test.startTest();
    try {
      new ApiHttpClient().sendAll(requests);
      Assert.fail('Invalid second request');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_REQUEST', failure.code, 'Preflight rejection');
    }
    Assert.areEqual(0, Limits.getCallouts(), 'First request must not be sent');
    Test.stopTest();
  }

  @IsTest
  static void emptyBatchDoesNothing() {
    Test.startTest();
    List<ApiCalloutResult> result = new ApiHttpClient()
      .sendAll(new List<ApiRequest>());
    Assert.areEqual(0, Limits.getCallouts(), 'Empty input has no side effects');
    Test.stopTest();

    Assert.areEqual(0, result.size(), 'Empty output');
  }

  @IsTest
  static void rejectsNullBatch() {
    Test.startTest();
    try {
      new ApiHttpClient().sendAll(null);
      Assert.fail('Null list');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_REQUEST', failure.code, 'Typed null failure');
    }
    Test.stopTest();
  }

  @IsTest
  static void rejectsNullTransport() {
    Test.startTest();
    try {
      new ApiHttpClient((IApiTransport) null);
      Assert.fail('Missing transport');
    } catch (ApiException failure) {
      Assert.areEqual(
        'INVALID_TRANSPORT',
        failure.code,
        'Typed transport failure'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void handlesMissingTransportResponse() {
    Test.startTest();
    ApiCalloutResult result = new ApiHttpClient(new NullTransport())
      .send(HttpTestDataFactory.request('/ok'));
    Test.stopTest();

    Assert.areEqual(
      'CALLOUT_FAILED',
      result.error.code,
      'Null native response must not pass'
    );
  }

  @IsTest
  static void rejectsMalformedUpstreamJson() {
    ApiCalloutResult value = new ApiCalloutResult();
    value.body = '<html>error</html>';

    Test.startTest();
    try {
      value.readJson();
      Assert.fail('Invalid JSON');
    } catch (ApiException failure) {
      Assert.areEqual(
        'INVALID_UPSTREAM_JSON',
        failure.code,
        'Stable parsing error'
      );
    }
    Test.stopTest();
  }
}
