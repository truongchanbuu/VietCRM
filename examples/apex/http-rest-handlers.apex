// Local request/response objects only; this script does not expose a REST route.
RestRequest request = new RestRequest();
request.addHeader(
  'Content-Type',
  'application/vnd.partner+json; charset=UTF-8'
);
request.requestBody = Blob.valueOf('["first","second"]');
List<Object> untyped = (List<Object>) ApiRequestReader.readJson(request);
List<String> typed = (List<String>) ApiRequestReader.readAs(
  request,
  List<String>.class
);
IApiBodyFormatter formatter = new ApiJsonFormatter();
Assert.areEqual(
  typed,
  (List<String>) ApiRequestReader.readAs(request, List<String>.class, formatter)
);
Assert.areEqual(
  untyped,
  (List<Object>) ApiRequestReader.read(request, formatter)
);

RestResponse response = new RestResponse();
response.addHeader('Location', '/services/apexrest/application/items/example');
ApiWriter.created(response, typed, 'rest-example');
Assert.areEqual(201, response.statusCode);
Assert.areEqual('no-store', response.headers.get('Cache-Control'));

// An endpoint chooses one outcome. These are independent example responses.
RestResponse missing = new RestResponse();
ApiWriter.notFound(missing, 'The resource was not found.');
Assert.areEqual(404, missing.statusCode);
RestResponse empty = new RestResponse();
ApiWriter.noContent(empty);
Assert.isNull(empty.responseBody);

ApiException conflict = ApiException.create(
  409,
  'STALE_VERSION',
  'Refresh the resource.'
);
ApiResponse envelope = ApiGlobalExceptionHandler.toResponse(
  conflict,
  'rest-example'
);
Assert.areEqual('STALE_VERSION', envelope.error.code);
RestResponse failure = new RestResponse();
ApiGlobalExceptionHandler.handle(failure, conflict, 'rest-example');
Assert.areEqual(409, failure.statusCode);

RestResponse custom = new RestResponse();
ApiWriter.write(
  custom,
  200,
  ApiResponseFactory.success(typed, 'rest-example'),
  formatter
);
Assert.areEqual(200, custom.statusCode);
