@IsTest
private class ApiBodyCodecTest {
  private class StubCodecException extends Exception {
  }

  private class StubCodec implements IApiBodyCodec {
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
        throw new StubCodecException('sensitive encoder detail');
      return nullOutput ? null : 'encoded-body';
    }

    public Object decode(String value, System.Type targetType) {
      receivedType = targetType;
      if (fail)
        throw new StubCodecException('sensitive decoder detail');
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

  private static ApiRequest outbound(IApiBodyCodec codec) {
    ApiRequest request = new ApiRequest();
    request.endpoint = 'callout:Example/resource';
    request.method = 'POST';
    request.codec = codec;
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
  static void jsonCodecSupportsTypedUntypedAndVendorMedia() {
    ApiJsonCodec codec = new ApiJsonCodec();
    Assert.isTrue(
      codec.supports('Application/Vnd.example+JSON; charset=UTF-8')
    );
    Assert.isTrue(codec.supports('application/json'));
    Assert.isFalse(codec.supports(null));
    Assert.isFalse(codec.supports('text/json'));
    Assert.areEqual('null', codec.encode(null));
    List<String> values = new List<String>();
    for (Integer index = 0; index < 251; index++)
      values.add('value-' + index);
    Integer queries = Limits.getQueries();
    Integer dml = Limits.getDmlStatements();
    String body = codec.encode(values);
    Assert.areEqual(251, ((List<Object>) codec.decode(body, null)).size());
    Assert.areEqual(
      values,
      (List<String>) codec.decode(body, List<String>.class)
    );
    Assert.areEqual(queries, Limits.getQueries());
    Assert.areEqual(dml, Limits.getDmlStatements());
  }

  @IsTest
  static void customCodecFlowsThroughUnchangedTransport() {
    StubCodec codec = new StubCodec();
    RecordingTransport transport = new RecordingTransport();
    ApiCalloutResult result = new ApiHttpClient(transport)
      .send(outbound(codec));
    Assert.isTrue(result.isSuccess());
    Assert.areEqual(1, transport.calls);
    Assert.areEqual('custom-result', result.read(codec));
    Assert.areEqual('custom-result', result.readAs(String.class, codec));
    Assert.areEqual(String.class, codec.receivedType);
  }

  @IsTest
  static void explicitCompatibleMediaAndRawBodiesRemainSupported() {
    ApiRequest request = outbound(new StubCodec());
    request.headers.put(
      'content-type',
      'application/x-toolkit-test; version=2'
    );
    Assert.areEqual(
      'application/x-toolkit-test; version=2',
      ApiRequestBuilder.build(request).getHeader('Content-Type')
    );
    request.codec = null;
    request.payload = null;
    request.body = 'raw-text';
    Assert.areEqual('raw-text', ApiRequestBuilder.build(request).getBody());
  }

  @IsTest
  static void badCodecRequestsRejectBeforeAnyCallouts() {
    StubCodec codec = new StubCodec();
    RecordingTransport transport = new RecordingTransport();
    ApiRequest invalid = outbound(codec);
    invalid.body = 'conflict';
    expectInvalidBatch(transport, invalid);
    invalid.body = null;
    invalid.codec = null;
    expectInvalidBatch(transport, invalid);
    invalid.codec = codec;
    invalid.method = 'GET';
    expectInvalidBatch(transport, invalid);
    invalid.method = 'POST';
    invalid.headers.put('Content-Type', 'text/plain');
    expectInvalidBatch(transport, invalid);
    invalid.headers.clear();
    codec.nullOutput = true;
    expectInvalidBatch(transport, invalid);
    codec.nullOutput = false;
    codec.fail = true;
    expectInvalidBatch(transport, invalid);
    Assert.areEqual(0, transport.calls);
  }

  private static void expectInvalidBatch(
    RecordingTransport transport,
    ApiRequest invalid
  ) {
    try {
      new ApiHttpClient(transport)
        .sendAll(new List<ApiRequest>{ outbound(new StubCodec()), invalid });
      Assert.fail('Expected preflight rejection');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_REQUEST', failure.code);
      Assert.isFalse(failure.getMessage().contains('sensitive'));
    }
  }

  @IsTest
  static void restReaderPassesTypeAndMapsDecodeErrors() {
    StubCodec codec = new StubCodec();
    Assert.areEqual('custom-input', ApiRequestReader.read(inbound(), codec));
    Assert.areEqual(
      'custom-input',
      ApiRequestReader.readAs(inbound(), String.class, codec)
    );
    Assert.areEqual(String.class, codec.receivedType);
    codec.fail = true;
    try {
      ApiRequestReader.read(inbound(), codec);
      Assert.fail('Expected decoding error');
    } catch (ApiException failure) {
      Assert.areEqual(400, failure.statusCode);
      Assert.areEqual('INVALID_BODY', failure.code);
      Assert.isFalse(failure.getMessage().contains('sensitive'));
    }
  }

  @IsTest
  static void restReaderRejectsWrongMediaAndMissingCodec() {
    RestRequest request = inbound();
    request.headers.put('Content-Type', 'text/plain');
    try {
      ApiRequestReader.read(request, new StubCodec());
      Assert.fail('Expected media rejection');
    } catch (ApiException failure) {
      Assert.areEqual(415, failure.statusCode);
    }
    try {
      ApiRequestReader.read(request, null);
      Assert.fail('Expected missing codec');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_CODEC', failure.code);
    }
  }

  @IsTest
  static void calloutDecoderHandlesEmptyAndInvalidBodies() {
    StubCodec codec = new StubCodec();
    ApiCalloutResult result = new ApiCalloutResult();
    codec.fail = true;
    Assert.isNull(result.read(codec));
    result.body = 'invalid';
    try {
      result.read(codec);
      Assert.fail('Expected invalid upstream body');
    } catch (ApiException failure) {
      Assert.areEqual(500, failure.statusCode);
      Assert.areEqual('INVALID_UPSTREAM_BODY', failure.code);
      Assert.isFalse(failure.getMessage().contains('sensitive'));
    }
    try {
      result.read(null);
      Assert.fail('Expected missing codec');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_CODEC', failure.code);
    }
    try {
      result.readAs(null, codec);
      Assert.fail('Expected missing type');
    } catch (ApiException failure) {
      Assert.areEqual('INVALID_CODEC', failure.code);
    }
  }

  @IsTest
  static void writerUsesCustomCodecAndSkipsBodylessEncoding() {
    StubCodec codec = new StubCodec();
    RestResponse response = new RestResponse();
    response.addHeader('X-Correlation', 'preserved');
    ApiWriter.write(
      response,
      201,
      ApiResponseFactory.success('data', 'id'),
      codec
    );
    Assert.areEqual(201, response.statusCode);
    Assert.areEqual('encoded-body', response.responseBody.toString());
    Assert.areEqual(
      'application/x-toolkit-test',
      response.headers.get('Content-Type')
    );
    Assert.areEqual('no-store', response.headers.get('Cache-Control'));
    Assert.areEqual('preserved', response.headers.get('X-Correlation'));
    codec.fail = true;
    ApiWriter.write(
      response,
      204,
      ApiResponseFactory.success(null, null),
      codec
    );
    Assert.isNull(response.responseBody);
    ApiWriter.write(
      response,
      304,
      ApiResponseFactory.failed('UNCHANGED', 'Unchanged', null),
      codec
    );
    Assert.isNull(response.responseBody);
    Assert.areEqual(1, codec.encodes);
  }

  @IsTest
  static void writerFailuresDoNotMutateResponse() {
    StubCodec codec = new StubCodec();
    codec.fail = true;
    expectWriterFailure(codec);
    codec.fail = false;
    codec.nullOutput = true;
    expectWriterFailure(codec);
    codec.contentType = 'unsafe\r\nInjected: true';
    expectWriterFailure(codec);
    codec.contentType = '';
    expectWriterFailure(codec);
    expectWriterFailure(null);
  }

  private static void expectWriterFailure(IApiBodyCodec codec) {
    RestResponse response = new RestResponse();
    response.statusCode = 202;
    response.responseBody = Blob.valueOf('original');
    response.addHeader('Content-Type', 'original/type');
    try {
      ApiWriter.write(
        response,
        200,
        ApiResponseFactory.success('data', null),
        codec
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
