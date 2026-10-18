// No network or database work. Deploy the HTTP module before running.
ApiRequest request = new ApiRequest();
request.endpoint = 'callout:Partner_API/v1/items';
request.method = 'POST';
request.timeoutMillis = 5000;
request.requestId = 'bulk-example';
request.headers.put('X-Request-Id', request.requestId);
request.queryParameters.put('label', 'ready & waiting');
request.formatter = new ApiJsonFormatter();
List<Object> items = new List<Object>();
for (Integer index = 0; index < 251; index++) {
  items.add(new Map<String, Object>{ 'reference' => 'item-' + index });
}
request.payload = items;
HttpRequest prepared = ApiRequestBuilder.build(request);
Assert.areEqual('POST', prepared.getMethod());
Assert.isTrue(prepared.getEndpoint().contains('label=ready+%26+waiting'));
Assert.areEqual(
  251,
  ((List<Object>) JSON.deserializeUntyped(prepared.getBody())).size()
);

// Alternative raw text path: set the media type and clear payload/formatter.
request.formatter = null;
request.payload = null;
request.headers.put('Content-Type', 'text/plain; charset=UTF-8');
request.body = 'caller-owned raw text';
Assert.areEqual(request.body, ApiRequestBuilder.build(request).getBody());
