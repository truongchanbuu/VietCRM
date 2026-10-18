/** Envelope factories preserve isolation and bulk data without transport side effects. */
@IsTest
private class ApiResponseFactoryTest {
  @IsTest
  static void successPreservesBulkData() {
    List<Integer> data = new List<Integer>();
    for (Integer i = 0; i < 251; i++) {
      data.add(i);
    }

    Test.startTest();
    ApiResponse response = ApiResponseFactory.success(data, 'bulk-id');
    Assert.areEqual(0, Limits.getQueries(), 'Factory must not query');
    Assert.areEqual(0, Limits.getDmlStatements(), 'Factory must not write');
    Assert.areEqual(0, Limits.getCallouts(), 'Factory must not call out');
    Test.stopTest();

    Assert.isTrue(response.success, 'Successful envelope');
    Assert.areEqual(data, response.data, 'Preserve the full collection');
    Assert.isNull(response.error, 'No error on success');
    Assert.areEqual('bulk-id', response.requestId, 'Keep correlation');
  }

  @IsTest
  static void successAllowsNullData() {
    Test.startTest();
    ApiResponse response = ApiResponseFactory.success(null, null);
    Test.stopTest();

    Assert.isTrue(response.success, 'Null data is a valid success result');
    Assert.isNull(response.data, 'Preserve null');
    Assert.isNull(response.requestId, 'Correlation is optional');
  }

  @IsTest
  static void failuresAreFreshAndCarryNoData() {
    Test.startTest();
    ApiResponse first = ApiResponseFactory.failed('MISSING', 'Not found.', 'a');
    ApiResponse second = ApiResponseFactory.failed(
      'MISSING',
      'Not found.',
      'b'
    );
    first.error.message = 'Changed';
    Test.stopTest();

    Assert.isFalse(second.success, 'Failure envelope');
    Assert.isNull(second.data, 'No successful data on errors');
    Assert.areEqual('MISSING', second.error.code, 'Retain application code');
    Assert.areEqual(
      'Not found.',
      second.error.message,
      'Errors cannot leak state across calls'
    );
    Assert.areEqual(
      'b',
      second.requestId,
      'Correlation cannot leak across calls'
    );
  }

  @IsTest
  static void internalErrorIsSafe() {
    Test.startTest();
    ApiResponse response = ApiResponseFactory.internalError('trace');
    Test.stopTest();

    Assert.isFalse(response.success, 'Fallback is a failure');
    Assert.areEqual(
      'INTERNAL_ERROR',
      response.error.code,
      'Stable fallback code'
    );
    Assert.areEqual(
      'An unexpected error occurred.',
      response.error.message,
      'Safe public fallback'
    );
    Assert.areEqual('trace', response.requestId, 'Retain correlation');
  }

  @IsTest
  static void rejectsMissingErrorCode() {
    assertInvalid(null, 'Safe message');
  }
  @IsTest
  static void rejectsBlankErrorCode() {
    assertInvalid(' ', 'Safe message');
  }
  @IsTest
  static void rejectsMissingErrorMessage() {
    assertInvalid('ERROR', null);
  }
  @IsTest
  static void rejectsBlankErrorMessage() {
    assertInvalid('ERROR', ' ');
  }

  private static void assertInvalid(String code, String message) {
    Test.startTest();
    try {
      ApiResponseFactory.failed(code, message, null);
      Assert.fail('Incomplete public errors must be rejected');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_RESPONSE', failure.code, 'Configuration error');
    }
    Test.stopTest();
  }
}
