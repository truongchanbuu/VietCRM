// Makes TWO real GET requests when explicitly executed. Configure Partner_API first.
// Change these paths to endpoints you own. Complete callouts before application DML.
List<ApiRequest> requests = new List<ApiRequest>();
for (String path : new List<String>{ '/v1/health', '/v1/status' }) {
  ApiRequest request = new ApiRequest();
  request.path = path;
  request.timeoutMillis = 5000;
  request.requestId = path;
  requests.add(request);
}
try {
  List<ApiCalloutResult> results = new ApiHttpClient('callout:Partner_API')
    .sendAll(requests);
  Assert.areEqual(requests.size(), results.size());
  for (Integer index = 0; index < results.size(); index++) {
    ApiCalloutResult result = results[index];
    Assert.areEqual(requests[index].requestId, result.requestId);
    if (result.isSuccess()) {
      // Consume result.body or explicitly decode using readJson/read/readAs.
    } else {
      // Inspect result.error.code; apply application-owned retry/persistence policy.
      Assert.isNotNull(result.error);
    }
  }
} catch (ApiException failure) {
  // Whole-batch preflight failure: no new callout was sent.
  // CALLOUT_BUDGET_EXCEEDED requires separate transactions; invalid input needs a fix.
  throw failure;
}
