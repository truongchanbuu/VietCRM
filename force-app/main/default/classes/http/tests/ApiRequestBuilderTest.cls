/** Request validation, encoding, header safety and native defaults. */
@IsTest
private class ApiRequestBuilderTest {
  @IsTest
  static void buildsNamedCredentialRequest() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.endpoint = 'callout:Partner_API/v1/items?existing=true';
    request.method = ' post ';
    request.body = '{"items":[1,2]}';
    request.timeoutMillis = 120000;
    request.headers.put('Content-Type', 'application/json');
    request.queryParameters.put('q', 'a & b');
    request.queryParameters.put('page', '1');

    Test.startTest();
    HttpRequest actual = ApiRequestBuilder.build(request);
    Test.stopTest();

    Assert.areEqual(
      'callout:Partner_API/v1/items?existing=true&page=1&q=a+%26+b',
      actual.getEndpoint(),
      'Query values must be encoded once and keys sorted'
    );
    Assert.areEqual('POST', actual.getMethod(), 'Methods must be canonical');
    Assert.areEqual(request.body, actual.getBody(), 'Body must be unchanged');
    Assert.areEqual(
      'application/json',
      actual.getHeader('Content-Type'),
      'Developer-selected content type must survive'
    );
  }

  @IsTest
  static void allowsCommonMethods() {
    Test.startTest();
    for (
      String method : new List<String>{
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
        'HEAD',
        'OPTIONS'
      }
    ) {
      ApiRequest request = HttpTestDataFactory.request('/ok');
      request.method = method;
      Assert.areEqual(
        method,
        ApiRequestBuilder.build(request).getMethod(),
        'Supported method'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void allowsNullOptionalMaps() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.headers = null;
    request.queryParameters = null;

    Test.startTest();
    HttpRequest actual = ApiRequestBuilder.build(request);
    Test.stopTest();

    Assert.areEqual(
      request.endpoint,
      actual.getEndpoint(),
      'No query must be added'
    );
  }

  @IsTest
  static void rejectsNullRequest() {
    assertInvalid(null);
  }

  @IsTest
  static void rejectsHttpEndpoint() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.endpoint = 'http://example.invalid';
    assertInvalid(request);
  }

  @IsTest
  static void rejectsEndpointCredentials() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.endpoint = 'https://user:password@example.invalid';
    assertInvalid(request);
  }

  @IsTest
  static void rejectsEndpointInjection() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.endpoint += '\r\nX-Test:true';
    assertInvalid(request);
  }

  @IsTest
  static void rejectsBlankEndpoint() {
    ApiRequest request = new ApiRequest();
    assertInvalid(request);
  }

  @IsTest
  static void rejectsUnsupportedMethod() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.method = 'TRACE';
    assertInvalid(request);
  }

  @IsTest
  static void rejectsMissingMethod() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.method = null;
    assertInvalid(request);
  }

  @IsTest
  static void rejectsGetBody() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.body = '{}';
    assertInvalid(request);
  }

  @IsTest
  static void rejectsHeadBody() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.method = 'HEAD';
    request.body = '{}';
    assertInvalid(request);
  }

  @IsTest
  static void rejectsZeroTimeout() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.timeoutMillis = 0;
    assertInvalid(request);
  }

  @IsTest
  static void rejectsLargeTimeout() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.timeoutMillis = 120001;
    assertInvalid(request);
  }

  @IsTest
  static void rejectsNullTimeout() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.timeoutMillis = null;
    assertInvalid(request);
  }

  @IsTest
  static void rejectsHeaderNewline() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.headers.put('X-Test', 'ok\nInjected:true');
    assertInvalid(request);
  }

  @IsTest
  static void rejectsHeaderName() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.headers.put('bad name', 'ok');
    assertInvalid(request);
  }

  @IsTest
  static void rejectsDuplicateHeaders() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.headers.put('X-Test', 'one');
    request.headers.put('x-test', 'two');
    assertInvalid(request);
  }

  @IsTest
  static void rejectsManagedHeader() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.headers.put('Content-Length', '99');
    assertInvalid(request);
  }

  @IsTest
  static void rejectsNullHeaderValue() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.headers.put('X-Test', null);
    assertInvalid(request);
  }

  @IsTest
  static void rejectsNullQueryValue() {
    ApiRequest request = HttpTestDataFactory.request('/ok');
    request.queryParameters.put('q', null);
    assertInvalid(request);
  }

  private static void assertInvalid(ApiRequest request) {
    Test.startTest();
    try {
      ApiRequestBuilder.build(request);
      Assert.fail('Invalid request must fail');
    } catch (ApiException failure) {
      Assert.areEqual(
        'INVALID_REQUEST',
        failure.code,
        'Typed validation error'
      );
    }
    Assert.areEqual(0, Limits.getCallouts(), 'Builder must never call out');
    Test.stopTest();
  }
}
