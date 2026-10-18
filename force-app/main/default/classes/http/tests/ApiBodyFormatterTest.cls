@IsTest
private class ApiBodyFormatterTest {
  private class StubFormatterException extends Exception {
  }

  private class StubFormatter implements IApiBodyFormatter {
    String contentType = 'application/x-toolkit-test';
    Boolean fail = false;
    Boolean nullOutput = false;
    Integer encodes = 0;
    System.Type receivedType;

    public String getContentType() {
      return contentType;
    }

    public Boolean supports(String value) {
      return value != null && value.startsWith('application/x-toolkit-test');
    }

    public String encode(Object value) {
      encodes++;
      if (fail)
        throw new StubFormatterException('sensitive encoder detail');
      return nullOutput ? null : 'encoded-body';
    }

    public Object decode(String value, System.Type targetType) {
      receivedType = targetType;
      if (fail)
        throw new StubFormatterException('sensitive decoder detail');
      return value;
    }
  }

  private class RecordingTransport implements IApiTransport {
    Integer calls = 0;
    public HttpResponse send(HttpRequest request) {
      calls++;
      Assert.areEqual('encoded-body', request.getBody());
      Assert.areEqual(
        'application/x-toolkit-test',
        request.getHeader('Content-Type')
      );
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody('custom-result');
      return response;
    }
  }

  private static ApiRequest outbound(IApiBodyFormatter formatter) {
    ApiRequest request = new ApiRequest();
    request.endpoint = 'callout:Example/resource';
    request.method = 'POST';
    request.formatter = formatter;
    request.payload = new Map<String, Object>{ 'name' => 'sample' };
    return request;
  }

  private static RestRequest inbound() {
    RestRequest request = new RestRequest();
    request.addHeader('Content-Type', 'application/x-toolkit-test');
    request.requestBody = Blob.valueOf('custom-input');
    return request;
  }

  @IsTest
  static void jsonFormatterSupportsTypedUntypedAndVendorMedia() {
    ApiJsonFormatter formatter = new ApiJsonFormatter();
    Assert.isTrue(
      formatter.supports('Application/Vnd.example+JSON; charset=UTF-8')
    );
    Assert.isTrue(formatter.supports('application/json'));
    Assert.isFalse(formatter.supports(null));
    Assert.isFalse(formatter.supports('text/json'));
    Assert.areEqual('null', formatter.encode(null));
    List<String> values = new List<String>();
    for (Integer index = 0; index < 251; index++)
      values.add('value-' + index);
    Integer queries = Limits.getQueries();
    Integer dml = Limits.getDmlStatements();
    String body = formatter.encode(values);
    Assert.areEqual(251, ((List<Object>) formatter.decode(body, null)).size());
    Assert.areEqual(
      values,
      (List<String>) formatter.decode(body, List<String>.class)
    );
    Assert.areEqual(queries, Limits.getQueries());
    Assert.areEqual(dml, Limits.getDmlStatements());
  }

  @IsTest
  static void customFormatterFlowsThroughUnchangedTransport() {
    StubFormatter formatter = new StubFormatter();
    RecordingTransport transport = new RecordingTransport();
    ApiCalloutResult result = new ApiHttpClient(transport)
      .send(outbound(formatter));
    Assert.isTrue(result.isSuccess());
    Assert.areEqual(1, transport.calls);
    Assert.areEqual('custom-result', result.read(formatter));
    Assert.areEqual('custom-result', result.readAs(String.class, formatter));
    Assert.areEqual(String.class, formatter.receivedType);
  }

  @IsTest
  static void explicitCompatibleMediaAndRawBodiesRemainSupported() {
    ApiRequest request = outbound(new StubFormatter());
    request.headers.put(
      'content-type',
      'application/x-toolkit-test; version=2'
    );
    Assert.areEqual(
      'application/x-toolkit-test; version=2',
      ApiRequestBuilder.build(request).getHeader('Content-Type')
    );
    request.formatter = null;
    request.payload = null;
    request.body = 'raw-text';
    Assert.areEqual('raw-text', ApiRequestBuilder.build(request).getBody());
  }

  @IsTest
  static void badFormatterRequestsRejectBeforeAnyCallouts() {
    StubFormatter formatter = new StubFormatter();
    RecordingTransport transport = new RecordingTransport();
    ApiRequest invalid = outbound(formatter);
    invalid.body = 'conflict';
    expectInvalidBatch(transport, invalid);
    invalid.body = null;
    invalid.formatter = null;
    expectInvalidBatch(transport, invalid);
    invalid.formatter = formatter;
    invalid.method = 'GET';
    expectInvalidBatch(transport, invalid);
    invalid.method = 'POST';
    invalid.headers.put('Content-Type', 'text/plain');
    expectInvalidBatch(transport, invalid);
    invalid.headers.clear();
    formatter.nullOutput = true;
    expectInvalidBatch(transport, invalid);
    formatter.nullOutput = false;
    formatter.fail = true;
    expectInvalidBatch(transport, invalid);
    Assert.areEqual(0, transport.calls);
  }

  private static void expectInvalidBatch(
    RecordingTransport transport,
    ApiRequest invalid
  ) {
    try {
      new ApiHttpClient(transport)
        .sendAll(
          new List<ApiRequest>{ outbound(new StubFormatter()), invalid }
        );
      Assert.fail('Expected preflight rejection');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_REQUEST', failure.code);
      Assert.isFalse(failure.getMessage().contains('sensitive'));
    }
  }

  @IsTest
  static void restReaderPassesTypeAndMapsDecodeErrors() {
    StubFormatter formatter = new StubFormatter();
    Assert.areEqual(
      'custom-input',
      ApiRequestReader.read(inbound(), formatter)
    );
    Assert.areEqual(
      'custom-input',
      ApiRequestReader.readAs(inbound(), String.class, formatter)
    );
    Assert.areEqual(String.class, formatter.receivedType);
    formatter.fail = true;
    try {
      ApiRequestReader.read(inbound(), formatter);
      Assert.fail('Expected decoding error');
    } catch (ApiException failure) {
      Assert.areEqual(400, failure.statusCode);
      Assert.areEqual('INVALID_BODY', failure.code);
      Assert.isFalse(failure.getMessage().contains('sensitive'));
    }
  }

  @IsTest
  static void restReaderRejectsWrongMediaAndMissingFormatter() {
    RestRequest request = inbound();
    request.headers.put('Content-Type', 'text/plain');
    try {
      ApiRequestReader.read(request, new StubFormatter());
      Assert.fail('Expected media rejection');
    } catch (ApiException failure) {
      Assert.areEqual(415, failure.statusCode);
    }
    try {
      ApiRequestReader.read(request, null);
      Assert.fail('Expected missing formatter');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_FORMATTER', failure.code);
    }
  }

  @IsTest
  static void calloutDecoderHandlesEmptyAndInvalidBodies() {
    StubFormatter formatter = new StubFormatter();
    ApiCalloutResult result = new ApiCalloutResult();
    formatter.fail = true;
    Assert.isNull(result.read(formatter));
    result.body = 'invalid';
    try {
      result.read(formatter);
      Assert.fail('Expected invalid upstream body');
    } catch (ApiException failure) {
      Assert.areEqual(500, failure.statusCode);
      Assert.areEqual('INVALID_UPSTREAM_BODY', failure.code);
      Assert.isFalse(failure.getMessage().contains('sensitive'));
    }
    try {
      result.read(null);
      Assert.fail('Expected missing formatter');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_FORMATTER', failure.code);
    }
    try {
      result.readAs(null, formatter);
      Assert.fail('Expected missing type');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_FORMATTER', failure.code);
    }
  }

  @IsTest
  static void writerUsesCustomFormatterAndSkipsBodylessEncoding() {
    StubFormatter formatter = new StubFormatter();
    RestResponse response = new RestResponse();
    response.addHeader('X-Correlation', 'preserved');
    ApiWriter.write(
      response,
      201,
      ApiResponseFactory.success('data', 'id'),
      formatter
    );
    Assert.areEqual(201, response.statusCode);
    Assert.areEqual('encoded-body', response.responseBody.toString());
    Assert.areEqual(
      'application/x-toolkit-test',
      response.headers.get('Content-Type')
    );
    Assert.areEqual('no-store', response.headers.get('Cache-Control'));
    Assert.areEqual('preserved', response.headers.get('X-Correlation'));
    formatter.fail = true;
    ApiWriter.write(
      response,
      204,
      ApiResponseFactory.success(null, null),
      formatter
    );
    Assert.isNull(response.responseBody);
    ApiWriter.write(
      response,
      304,
      ApiResponseFactory.failed('UNCHANGED', 'Unchanged', null),
      formatter
    );
    Assert.isNull(response.responseBody);
    Assert.areEqual(1, formatter.encodes);
  }

  @IsTest
  static void writerFailuresDoNotMutateResponse() {
    StubFormatter formatter = new StubFormatter();
    formatter.fail = true;
    expectWriterFailure(formatter);
    formatter.fail = false;
    formatter.nullOutput = true;
    expectWriterFailure(formatter);
    formatter.contentType = 'unsafe\r\nInjected: true';
    expectWriterFailure(formatter);
    formatter.contentType = '';
    expectWriterFailure(formatter);
    expectWriterFailure(null);
  }

  private static void expectWriterFailure(IApiBodyFormatter formatter) {
    RestResponse response = new RestResponse();
    response.statusCode = 202;
    response.responseBody = Blob.valueOf('original');
    response.addHeader('Content-Type', 'original/type');
    try {
      ApiWriter.write(
        response,
        200,
        ApiResponseFactory.success('data', null),
        formatter
      );
      Assert.fail('Expected invalid response');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_RESPONSE', failure.code);
      Assert.isFalse(failure.getMessage().contains('sensitive'));
    }
    Assert.areEqual(202, response.statusCode);
    Assert.areEqual('original', response.responseBody.toString());
    Assert.areEqual('original/type', response.headers.get('Content-Type'));
  }
}
