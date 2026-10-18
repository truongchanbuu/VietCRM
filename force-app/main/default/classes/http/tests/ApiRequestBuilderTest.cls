/** Request validation, encoding, header safety and native defaults. */
@IsTest
private class ApiRequestBuilderTest {
  @IsTest
  static void buildsNamedCredentialRequest() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.endpoint = 'callout:Partner_API/v1/items?existing=true';
    value.method = ' post ';
    value.body = '{"items":[1,2]}';
    value.timeoutMillis = 120000;
    value.headers.put('Content-Type', 'application/json');
    value.queryParameters.put('q', 'a & b');
    value.queryParameters.put('page', '1');
    Test.startTest();
    HttpRequest actual = ApiRequestBuilder.build(value);
    Test.stopTest();
    Assert.areEqual(
      'callout:Partner_API/v1/items?existing=true&page=1&q=a+%26+b',
      actual.getEndpoint(),
      'Query values must be encoded once and keys sorted'
    );
    Assert.areEqual('POST', actual.getMethod(), 'Methods must be canonical');
    Assert.areEqual(value.body, actual.getBody(), 'Body must be unchanged');
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
      ApiRequest value = HttpTestDataFactory.request('/ok');
      value.method = method;
      Assert.areEqual(
        method,
        ApiRequestBuilder.build(value).getMethod(),
        'Supported method'
      );
    }
    Test.stopTest();
  }
  @IsTest
  static void allowsNullOptionalMaps() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.headers = null;
    value.queryParameters = null;
    Test.startTest();
    HttpRequest actual = ApiRequestBuilder.build(value);
    Test.stopTest();
    Assert.areEqual(
      value.endpoint,
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
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.endpoint = 'http://example.invalid';
    assertInvalid(value);
  }
  @IsTest
  static void rejectsEndpointCredentials() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.endpoint = 'https://user:password@example.invalid';
    assertInvalid(value);
  }
  @IsTest
  static void rejectsEndpointInjection() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.endpoint += '\r\nX-Test:true';
    assertInvalid(value);
  }
  @IsTest
  static void rejectsBlankEndpoint() {
    ApiRequest value = new ApiRequest();
    assertInvalid(value);
  }
  @IsTest
  static void rejectsUnsupportedMethod() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.method = 'TRACE';
    assertInvalid(value);
  }
  @IsTest
  static void rejectsMissingMethod() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.method = null;
    assertInvalid(value);
  }
  @IsTest
  static void rejectsGetBody() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.body = '{}';
    assertInvalid(value);
  }
  @IsTest
  static void rejectsHeadBody() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.method = 'HEAD';
    value.body = '{}';
    assertInvalid(value);
  }
  @IsTest
  static void rejectsZeroTimeout() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.timeoutMillis = 0;
    assertInvalid(value);
  }
  @IsTest
  static void rejectsLargeTimeout() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.timeoutMillis = 120001;
    assertInvalid(value);
  }
  @IsTest
  static void rejectsNullTimeout() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.timeoutMillis = null;
    assertInvalid(value);
  }
  @IsTest
  static void rejectsHeaderNewline() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.headers.put('X-Test', 'ok\nInjected:true');
    assertInvalid(value);
  }
  @IsTest
  static void rejectsHeaderName() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.headers.put('bad name', 'ok');
    assertInvalid(value);
  }
  @IsTest
  static void rejectsDuplicateHeaders() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.headers.put('X-Test', 'one');
    value.headers.put('x-test', 'two');
    assertInvalid(value);
  }
  @IsTest
  static void rejectsManagedHeader() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.headers.put('Content-Length', '99');
    assertInvalid(value);
  }
  @IsTest
  static void rejectsNullHeaderValue() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.headers.put('X-Test', null);
    assertInvalid(value);
  }
  @IsTest
  static void rejectsNullQueryValue() {
    ApiRequest value = HttpTestDataFactory.request('/ok');
    value.queryParameters.put('q', null);
    assertInvalid(value);
  }
  private static void assertInvalid(ApiRequest value) {
    Test.startTest();
    try {
      ApiRequestBuilder.build(value);
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
