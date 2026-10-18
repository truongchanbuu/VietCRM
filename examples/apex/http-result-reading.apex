// Local result fixtures only. ApiHttpClient normally constructs these results.
ApiCalloutResult result = new ApiCalloutResult();
result.statusCode = 200;
result.requestId = 'result-example';
result.headers.put('content-type', 'application/json');
result.body = '["ready"]';
Assert.isTrue(result.isSuccess());
Assert.areEqual(1, ((List<Object>) result.readJson()).size());
IApiBodyFormatter formatter = new ApiJsonFormatter();
Assert.areEqual(1, ((List<Object>) result.read(formatter)).size());
Assert.areEqual(
  new List<String>{ 'ready' },
  (List<String>) result.readAs(List<String>.class, formatter)
);
result.body = '';
Assert.isNull(result.read(formatter));

// HTTP failures retain status, headers and raw body for trusted server-side code.
result.statusCode = 503;
result.error = new ApiError(
  'HTTP_ERROR',
  'Upstream service returned HTTP 503.'
);
Assert.isFalse(result.isSuccess());
// Transport failures instead have CALLOUT_FAILED and may have no status/body.
// Do not forward raw upstream bodies or headers to public REST clients.
