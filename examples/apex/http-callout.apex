// Makes one real GET request. Configure Partner_API and its principal access first.
ApiCalloutResult response = new ApiHttpClient()
  .get('callout:Partner_API/v1/health');
Assert.isTrue(
  response.isSuccess(),
  'Check the partner response and Named Credential configuration'
);
