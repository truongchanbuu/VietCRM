/** Named writer methods bind documented statuses and preserve the public envelope. */
@IsTest
private class ApiWriterHelpersTest {
  @IsTest
  static void successWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.success(target, 'result');
    Test.stopTest();

    Map<String, Object> body = readBody(target);
    Assert.areEqual(200, target.statusCode, 'Named success status');
    Assert.areEqual(true, body.get('success'), 'Success flag');
    Assert.areEqual('result', body.get('data'), 'Unchanged application data');
    Assert.isNull(body.get('error'), 'No error on success');
    Assert.areEqual(null, body.get('requestId'), 'Correlation contract');
  }

  @IsTest
  static void successWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.success(target, 'result', 'trace');
    Test.stopTest();

    Map<String, Object> body = readBody(target);
    Assert.areEqual(200, target.statusCode, 'Named success status');
    Assert.areEqual(true, body.get('success'), 'Success flag');
    Assert.areEqual('result', body.get('data'), 'Unchanged application data');
    Assert.isNull(body.get('error'), 'No error on success');
    Assert.areEqual('trace', body.get('requestId'), 'Correlation contract');
  }

  @IsTest
  static void createdWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.created(target, 'result');
    Test.stopTest();

    Map<String, Object> body = readBody(target);
    Assert.areEqual(201, target.statusCode, 'Named success status');
    Assert.areEqual(true, body.get('success'), 'Success flag');
    Assert.areEqual('result', body.get('data'), 'Unchanged application data');
    Assert.isNull(body.get('error'), 'No error on success');
    Assert.areEqual(null, body.get('requestId'), 'Correlation contract');
  }

  @IsTest
  static void createdWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.created(target, 'result', 'trace');
    Test.stopTest();

    Map<String, Object> body = readBody(target);
    Assert.areEqual(201, target.statusCode, 'Named success status');
    Assert.areEqual(true, body.get('success'), 'Success flag');
    Assert.areEqual('result', body.get('data'), 'Unchanged application data');
    Assert.isNull(body.get('error'), 'No error on success');
    Assert.areEqual('trace', body.get('requestId'), 'Correlation contract');
  }

  @IsTest
  static void acceptedWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.accepted(target, 'result');
    Test.stopTest();

    Map<String, Object> body = readBody(target);
    Assert.areEqual(202, target.statusCode, 'Named success status');
    Assert.areEqual(true, body.get('success'), 'Success flag');
    Assert.areEqual('result', body.get('data'), 'Unchanged application data');
    Assert.isNull(body.get('error'), 'No error on success');
    Assert.areEqual(null, body.get('requestId'), 'Correlation contract');
  }

  @IsTest
  static void acceptedWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.accepted(target, 'result', 'trace');
    Test.stopTest();

    Map<String, Object> body = readBody(target);
    Assert.areEqual(202, target.statusCode, 'Named success status');
    Assert.areEqual(true, body.get('success'), 'Success flag');
    Assert.areEqual('result', body.get('data'), 'Unchanged application data');
    Assert.isNull(body.get('error'), 'No error on success');
    Assert.areEqual('trace', body.get('requestId'), 'Correlation contract');
  }

  @IsTest
  static void badRequestWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.badRequest(target, 'Safe message.');
    Test.stopTest();

    assertFailure(target, 400, 'BAD_REQUEST', 'Safe message.', null);
  }

  @IsTest
  static void badRequestWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.badRequest(target, 'Safe message.', 'trace');
    Test.stopTest();

    assertFailure(target, 400, 'BAD_REQUEST', 'Safe message.', 'trace');
  }

  @IsTest
  static void unauthorizedWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.unauthorized(target, 'Safe message.');
    Test.stopTest();

    assertFailure(target, 401, 'UNAUTHORIZED', 'Safe message.', null);
  }

  @IsTest
  static void unauthorizedWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.unauthorized(target, 'Safe message.', 'trace');
    Test.stopTest();

    assertFailure(target, 401, 'UNAUTHORIZED', 'Safe message.', 'trace');
  }

  @IsTest
  static void forbiddenWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.forbidden(target, 'Safe message.');
    Test.stopTest();

    assertFailure(target, 403, 'FORBIDDEN', 'Safe message.', null);
  }

  @IsTest
  static void forbiddenWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.forbidden(target, 'Safe message.', 'trace');
    Test.stopTest();

    assertFailure(target, 403, 'FORBIDDEN', 'Safe message.', 'trace');
  }

  @IsTest
  static void notFoundWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.notFound(target, 'Safe message.');
    Test.stopTest();

    assertFailure(target, 404, 'NOT_FOUND', 'Safe message.', null);
  }

  @IsTest
  static void notFoundWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.notFound(target, 'Safe message.', 'trace');
    Test.stopTest();

    assertFailure(target, 404, 'NOT_FOUND', 'Safe message.', 'trace');
  }

  @IsTest
  static void conflictWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.conflict(target, 'Safe message.');
    Test.stopTest();

    assertFailure(target, 409, 'CONFLICT', 'Safe message.', null);
  }

  @IsTest
  static void conflictWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.conflict(target, 'Safe message.', 'trace');
    Test.stopTest();

    assertFailure(target, 409, 'CONFLICT', 'Safe message.', 'trace');
  }

  @IsTest
  static void serviceUnavailableWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.serviceUnavailable(target, 'Safe message.');
    Test.stopTest();

    assertFailure(target, 503, 'SERVICE_UNAVAILABLE', 'Safe message.', null);
  }

  @IsTest
  static void serviceUnavailableWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.serviceUnavailable(target, 'Safe message.', 'trace');
    Test.stopTest();

    assertFailure(target, 503, 'SERVICE_UNAVAILABLE', 'Safe message.', 'trace');
  }

  @IsTest
  static void createdPreserves251Items() {
    List<Integer> data = new List<Integer>();
    for (Integer i = 0; i < 251; i++) {
      data.add(i);
    }
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.created(target, data, 'bulk');
    Test.stopTest();

    Assert.areEqual(201, target.statusCode, 'Created collection');
    Assert.areEqual(
      251,
      ((List<Object>) readBody(target).get('data')).size(),
      'Every item must be written'
    );
  }

  @IsTest
  static void noContentClearsPreviousBody() {
    RestResponse target = new RestResponse();
    target.responseBody = Blob.valueOf('stale');

    Test.startTest();
    ApiWriter.noContent(target);
    Test.stopTest();

    Assert.areEqual(204, target.statusCode, 'No content status');
    Assert.isNull(target.responseBody, 'No stale or empty JSON representation');
    Assert.areEqual(
      'no-store',
      target.headers.get('Cache-Control'),
      'Preserve writer headers'
    );
  }

  @IsTest
  static void customFailedStatusWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.failed(
      target,
      412,
      new ApiError('STALE_VERSION', 'Refresh the resource.'),
      'trace'
    );
    Test.stopTest();

    assertFailure(
      target,
      412,
      'STALE_VERSION',
      'Refresh the resource.',
      'trace'
    );
  }

  @IsTest
  static void customFailedStatusWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.failed(target, 409, new ApiError('DUPLICATE', 'Already exists.'));
    Test.stopTest();

    assertFailure(target, 409, 'DUPLICATE', 'Already exists.', null);
  }

  @IsTest
  static void internalErrorWithoutCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.internalError(target);
    Test.stopTest();

    assertFailure(
      target,
      500,
      'INTERNAL_ERROR',
      'An unexpected error occurred.',
      null
    );
  }

  @IsTest
  static void internalErrorWithCorrelation() {
    RestResponse target = new RestResponse();

    Test.startTest();
    ApiWriter.internalError(target, 'trace');
    Test.stopTest();

    assertFailure(
      target,
      500,
      'INTERNAL_ERROR',
      'An unexpected error occurred.',
      'trace'
    );
  }

  @IsTest
  static void rejectsSuccessStatusForFailed() {
    assertInvalid(200, new ApiError('ERROR', 'Safe'));
  }
  @IsTest
  static void rejectsUnsupportedErrorStatus() {
    assertInvalid(429, new ApiError('ERROR', 'Safe'));
  }
  @IsTest
  static void rejectsNullErrorStatus() {
    assertInvalid(null, new ApiError('ERROR', 'Safe'));
  }
  @IsTest
  static void rejectsNullError() {
    assertInvalid(400, null);
  }
  @IsTest
  static void rejectsEmptyErrorCode() {
    assertInvalid(400, new ApiError(' ', 'Safe'));
  }
  @IsTest
  static void rejectsEmptyErrorMessage() {
    assertInvalid(400, new ApiError('ERROR', ' '));
  }

  private static void assertInvalid(Integer statusCode, ApiError error) {
    RestResponse target = new RestResponse();
    target.statusCode = 202;
    target.responseBody = Blob.valueOf('unchanged');

    Test.startTest();
    try {
      ApiWriter.failed(target, statusCode, error, null);
      Assert.fail('Invalid failures must not be written');
    } catch (ApiException failure) {
      Assert.areEqual(
        'INVALID_RESPONSE',
        failure.code,
        'Typed configuration error'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      202,
      target.statusCode,
      'Reject before changing the status'
    );
    Assert.areEqual(
      'unchanged',
      target.responseBody.toString(),
      'Reject before changing the body'
    );
  }

  private static Map<String, Object> readBody(RestResponse target) {
    return (Map<String, Object>) JSON.deserializeUntyped(
      target.responseBody.toString()
    );
  }

  private static void assertFailure(
    RestResponse target,
    Integer statusCode,
    String code,
    String message,
    String requestId
  ) {
    Map<String, Object> body = readBody(target);
    Map<String, Object> error = (Map<String, Object>) body.get('error');
    Assert.areEqual(statusCode, target.statusCode, 'Named error status');
    Assert.areEqual(false, body.get('success'), 'Failure flag');
    Assert.isNull(body.get('data'), 'No success data on failure');
    Assert.areEqual(code, error.get('code'), 'Stable error code');
    Assert.areEqual(message, error.get('message'), 'Explicit public message');
    Assert.areEqual(requestId, body.get('requestId'), 'Correlation contract');
    Assert.areEqual(
      'application/json; charset=UTF-8',
      target.headers.get('Content-Type'),
      'Shared JSON writer'
    );
  }
}
