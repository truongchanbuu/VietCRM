/** REST serialization, safe errors, bulk payloads, media types and malformed input. */
@IsTest
private class ApiRestHandlersTest {
  private class Payload {
    public String name;
  }
  @IsTest
  static void writes251ItemEnvelope() {
    List<Integer> data = new List<Integer>();
    for (Integer i = 0; i < 251; i++) {
      data.add(i);
    }
    RestResponse target = new RestResponse();
    Test.startTest();
    ApiWriter.success(target, 200, data, 'request-1');
    Test.stopTest();
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      target.responseBody.toString()
    );
    Assert.areEqual(200, target.statusCode, 'Success status');
    Assert.areEqual(
      251,
      ((List<Object>) payload.get('data')).size(),
      'Serialize entire collection once'
    );
    Assert.areEqual('request-1', payload.get('requestId'), 'Correlation id');
    Assert.areEqual(
      'no-store',
      target.headers.get('Cache-Control'),
      'Sensitive response caching disabled'
    );
    Assert.areEqual(
      'application/json; charset=UTF-8',
      target.headers.get('Content-Type'),
      'JSON media type'
    );
  }
  @IsTest
  static void writesNoContentWithoutBody() {
    RestResponse target = new RestResponse();
    target.responseBody = Blob.valueOf('old');
    Test.startTest();
    ApiWriter.success(target, 204, null, null);
    Test.stopTest();
    Assert.areEqual(204, target.statusCode, 'No content');
    Assert.isNull(target.responseBody, 'Clear prior body');
  }
  @IsTest
  static void writesCreatedNullData() {
    RestResponse target = new RestResponse();
    Test.startTest();
    ApiWriter.success(target, 201, null, null);
    Test.stopTest();
    Assert.areEqual(201, target.statusCode, 'Created status');
    Assert.areEqual(
      true,
      ((Map<String, Object>) JSON.deserializeUntyped(
          target.responseBody.toString()
        ))
        .get('success'),
      'Envelope success'
    );
  }
  @IsTest
  static void sanitizesUnexpectedException() {
    RestResponse target = new RestResponse();
    Test.startTest();
    ApiGlobalExceptionHandler.handle(
      target,
      new System.CalloutException('password secret upstream body'),
      'trace-1'
    );
    Test.stopTest();
    String body = target.responseBody.toString();
    Assert.areEqual(500, target.statusCode, 'Unexpected failure');
    Assert.isFalse(body.contains('password'), 'No exception details');
    Assert.isFalse(body.contains('stackTrace'), 'No stack trace');
    Assert.isTrue(body.contains('INTERNAL_ERROR'), 'Stable internal code');
    Assert.isTrue(body.contains('trace-1'), 'Correlation preserved');
  }
  @IsTest
  static void writesKnownApplicationError() {
    RestResponse target = new RestResponse();
    Test.startTest();
    ApiGlobalExceptionHandler.handle(
      target,
      ApiException.create(409, 'CONFLICT', 'Version conflict.'),
      'trace'
    );
    Test.stopTest();
    Assert.areEqual(
      409,
      target.statusCode,
      'Application-selected supported status'
    );
    Assert.isTrue(
      target.responseBody.toString().contains('Version conflict.'),
      'Only explicitly safe message is public'
    );
  }
  @IsTest
  static void fallsBackForUnsupportedErrorStatus() {
    RestResponse target = new RestResponse();
    Test.startTest();
    ApiGlobalExceptionHandler.handle(
      target,
      ApiException.create(429, 'RATE', 'private diagnostic'),
      null
    );
    Test.stopTest();
    Assert.areEqual(
      500,
      target.statusCode,
      'Unsupported Apex REST status becomes safe internal error'
    );
    Assert.isFalse(
      target.responseBody.toString().contains('private diagnostic'),
      'Malformed typed errors are not public'
    );
  }
  @IsTest
  static void handlesNullException() {
    Test.startTest();
    ApiResponse value = ApiGlobalExceptionHandler.toResponse(null, null);
    Test.stopTest();
    Assert.isFalse(value.success, 'Failure envelope');
    Assert.areEqual('INTERNAL_ERROR', value.error.code, 'Safe fallback');
  }
  @IsTest
  static void rejectsUnsupportedWriterStatus() {
    RestResponse target = new RestResponse();
    target.statusCode = 202;
    Test.startTest();
    try {
      ApiWriter.success(target, 299, 'data', null);
      Assert.fail('Unsupported status');
    } catch (ApiException failure) {
      Assert.areEqual(
        'INVALID_RESPONSE',
        failure.code,
        'Writer configuration error'
      );
    }
    Test.stopTest();
    Assert.areEqual(202, target.statusCode, 'Reject before changing target');
  }
  @IsTest
  static void rejectsMissingWriterTarget() {
    Test.startTest();
    try {
      ApiWriter.success(null, 200, null, null);
      Assert.fail('Missing target');
    } catch (ApiException failure) {
      Assert.areEqual(
        'INVALID_RESPONSE',
        failure.code,
        'Writer configuration error'
      );
    }
    Test.stopTest();
  }
  @IsTest
  static void rejectsContradictoryEnvelope() {
    ApiResponse payload = new ApiResponse();
    payload.success = true;
    payload.error = new ApiError('BAD', 'Bad');
    Test.startTest();
    try {
      ApiWriter.write(new RestResponse(), 200, payload);
      Assert.fail('Contradictory envelope');
    } catch (ApiException failure) {
      Assert.areEqual(
        'INVALID_RESPONSE',
        failure.code,
        'Writer configuration error'
      );
    }
    Test.stopTest();
  }
  @IsTest
  static void readsTypedJson() {
    RestRequest request = HttpTestDataFactory.inbound(
      '{"name":"Example","extra":true}',
      'application/json; charset=UTF-8'
    );
    Test.startTest();
    Payload value = (Payload) ApiRequestReader.readAs(request, Payload.class);
    Test.stopTest();
    Assert.areEqual(
      'Example',
      value.name,
      'Typed DTO with forward-compatible properties'
    );
  }
  @IsTest
  static void readsVendorJson() {
    RestRequest request = HttpTestDataFactory.inbound(
      '[1,2,3]',
      'application/vnd.example+json'
    );
    Test.startTest();
    List<Object> value = (List<Object>) ApiRequestReader.readJson(request);
    Test.stopTest();
    Assert.areEqual(3, value.size(), 'Vendor JSON collection');
  }
  @IsTest
  static void rejectsMalformedInboundJson() {
    assertReadFailure(
      HttpTestDataFactory.inbound('{', 'application/json'),
      'INVALID_JSON'
    );
  }
  @IsTest
  static void rejectsWrongMediaType() {
    assertReadFailure(
      HttpTestDataFactory.inbound('{}', 'text/plain'),
      'UNSUPPORTED_MEDIA_TYPE'
    );
  }
  @IsTest
  static void rejectsMissingMediaType() {
    assertReadFailure(
      HttpTestDataFactory.inbound('{}', null),
      'UNSUPPORTED_MEDIA_TYPE'
    );
  }
  @IsTest
  static void rejectsEmptyBody() {
    assertReadFailure(
      HttpTestDataFactory.inbound('   ', 'application/json'),
      'INVALID_REQUEST'
    );
  }
  @IsTest
  static void rejectsNullRequest() {
    assertReadFailure(null, 'INVALID_REQUEST');
  }
  @IsTest
  static void rejectsInvalidTypedJson() {
    Test.startTest();
    try {
      ApiRequestReader.readAs(
        HttpTestDataFactory.inbound('{', 'application/json'),
        Payload.class
      );
      Assert.fail('Malformed typed data');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_JSON', failure.code, 'Typed invalid JSON');
    }
    Test.stopTest();
  }
  @IsTest
  static void rejectsMissingDtoType() {
    Test.startTest();
    try {
      ApiRequestReader.readAs(
        HttpTestDataFactory.inbound('{}', 'application/json'),
        null
      );
      Assert.fail('Missing type');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_REQUEST', failure.code, 'Missing DTO');
    }
    Test.stopTest();
  }
  @IsTest
  static void readsCaseInsensitiveContentType() {
    RestRequest request = HttpTestDataFactory.inbound('{}', null);
    request.addHeader('CONTENT-TYPE', 'APPLICATION/JSON; charset=UTF-8');
    Test.startTest();
    Object result = ApiRequestReader.readJson(request);
    Test.stopTest();
    Assert.isNotNull(
      result,
      'HTTP header names and media types are case-insensitive'
    );
  }
  @IsTest
  static void rejectsBlankMediaType() {
    assertReadFailure(
      HttpTestDataFactory.inbound('{}', '; charset=UTF-8'),
      'UNSUPPORTED_MEDIA_TYPE'
    );
  }
  @IsTest
  static void rejectsInvalidUtf8Body() {
    RestRequest request = HttpTestDataFactory.inbound('{}', 'application/json');
    request.requestBody = EncodingUtil.convertFromHex('FF');
    assertReadFailure(request, 'INVALID_JSON');
  }
  private static void assertReadFailure(RestRequest value, String code) {
    Test.startTest();
    try {
      ApiRequestReader.readJson(value);
      Assert.fail('Expected parsing failure');
    } catch (ApiException failure) {
      Assert.areEqual(code, failure.code, 'Stable parsing code');
    }
    Test.stopTest();
  }
}
