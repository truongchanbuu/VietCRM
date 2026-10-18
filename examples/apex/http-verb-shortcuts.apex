// Makes real requests, including writes and a deletion, when explicitly executed.
// Configure a development Partner_API and replace these paths with your own test resources.
ApiHttpClient client = new ApiHttpClient();
Object payload = new Map<String, Object>{ 'reference' => 'toolkit-example' };
ApiCalloutResult fetched = client.get(
  'callout:Partner_API/v1/items/toolkit-example'
);
ApiCalloutResult created = client.post('callout:Partner_API/v1/items', payload);
ApiCalloutResult replaced = client.put(
  'callout:Partner_API/v1/items/toolkit-example',
  payload
);
ApiCalloutResult updated = client.patch(
  'callout:Partner_API/v1/items/toolkit-example',
  payload
);
// delete is reserved in Apex; deleteRequest issues the DELETE verb.
ApiCalloutResult deleted = client.deleteRequest(
  'callout:Partner_API/v1/items/toolkit-example'
);
// Each result has isSuccess(), raw body/status/headers, error, and explicit read methods.
