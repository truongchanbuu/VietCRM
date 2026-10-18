// Makes real requests, including writes and a deletion, when explicitly executed.
// Configure a development Partner_API and replace these paths with your own test resources.
ApiHttpClient client = new ApiHttpClient('callout:Partner_API');
Object payload = new Map<String, Object>{ 'reference' => 'toolkit-example' };
ApiCalloutResult fetched = client.get('/v1/items/toolkit-example');
ApiCalloutResult created = client.post('/v1/items', payload);
ApiCalloutResult replaced = client.put('/v1/items/toolkit-example', payload);
ApiCalloutResult updated = client.patch('/v1/items/toolkit-example', payload);
// delete is reserved in Apex; deleteRequest issues the DELETE verb.
ApiCalloutResult deleted = client.deleteRequest('/v1/items/toolkit-example');
// Each result has isSuccess(), raw body/status/headers, error, and explicit read methods.
