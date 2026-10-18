// Configure Partner_API and its principal access before running in a development org.
ApiRequest request = new ApiRequest();
request.endpoint = 'callout:Partner_API/v1/health';
request.requestId = 'developer-kit-example';
ApiCalloutResult response = new ApiHttpClient().send(request);
Assert.isTrue(
  response.isSuccess(),
  'Check the partner response and Named Credential configuration'
);
