# HTTP toolkit examples

These examples use `IApiBodyFormatter`, `ApiJsonFormatter`, and `request.formatter`. Deploy the HTTP module to a development org before running the scripts. They are opt-in examples outside `force-app`; no endpoint, business automation, or credential is installed automatically.

## Common calls

```apex
ApiHttpClient client = new ApiHttpClient();
ApiCalloutResult fetched = client.get('callout:Partner_API/v1/items');
ApiCalloutResult created = client.post('callout:Partner_API/v1/items', items);
ApiCalloutResult replaced = client.put('callout:Partner_API/v1/items/example', items);
ApiCalloutResult updated = client.patch('callout:Partner_API/v1/items/example', items);
ApiCalloutResult deleted = client.deleteRequest('callout:Partner_API/v1/items/example');
```

These are independent operation examples; `items` is application data. POST/PUT/PATCH serialize it as JSON, including JSON null for a null payload. String payloads are JSON strings; pass objects directly rather than pre-serializing them. GET/DELETE have no body. `deleteRequest` is named this way because Apex reserves `delete`. No request DTO or manual builder call is needed. Each shortcut returns the same `ApiCalloutResult` and uses the same endpoint validation, remaining callout budget, transport, and error handling as `send`/`sendAll`.

Use `send(ApiRequest)` when setting custom headers, query parameters, timeouts, correlation, raw bodies, or another formatter. For HEAD or OPTIONS, set `request.method` and use `send`. `sendAll` accepts a list of configured requests for ordered bulk outcomes. `ApiRequestBuilder` runs inside the client; direct use is only an optional preflight/inspection tool, demonstrated by the local request-building script.

| Feature | Example |
| --- | --- |
| Common GET/POST/PUT/PATCH/DELETE | [http-verb-shortcuts.apex](../apex/http-verb-shortcuts.apex) |
| Single GET, default native transport, Named Credential | [http-callout.apex](../apex/http-callout.apex) |
| Advanced preflight inspection: request fields, query encoding, headers, timeout, 251-item JSON payload, raw body | [http-request-building.apex](../apex/http-request-building.apex) |
| Ordered bulk calls, success/error outcomes, preflight failures | [http-bulk-callout.apex](../apex/http-bulk-callout.apex) |
| Raw results, success classification, untyped/typed/formatter decoding, empty responses | [http-result-reading.apex](../apex/http-result-reading.apex) |
| JSON/vendor media, typed/untyped readers, custom formatter selection, writing headers, bodyless response, safe exceptions | [http-rest-handlers.apex](../apex/http-rest-handlers.apex) |
| Every response helper, factory, supported statuses, legacy overloads | [http-response-helpers.apex](../apex/http-response-helpers.apex) and [Response helpers](#response-helpers) |
| Native and custom transport injection | [Transport injection](#transport-injection) |
| Formatter contract and injection at every boundary | [Formatter extension](#formatter-extension) |
| Outer REST exception boundary and envelope-only error mapping | [Endpoint boundary](#endpoint-boundary) |

Run a local-only example after deploying the module:

```sh
sf apex run --file examples/apex/http-request-building.apex --target-org dev
sf apex run --file examples/apex/http-result-reading.apex --target-org dev
sf apex run --file examples/apex/http-rest-handlers.apex --target-org dev
sf apex run --file examples/apex/http-response-helpers.apex --target-org dev
```

These four scripts use local request/response objects, make no callouts, and perform no SOQL/DML. `http-callout.apex` and `http-bulk-callout.apex` make real GET requests only when explicitly run; `http-verb-shortcuts.apex` additionally creates, updates, and deletes partner resources; configure `Partner_API`, principal access, and your own resource paths first.

## Response helpers

Each call below represents an **alternative endpoint outcome** and uses a fresh response. The last argument is a correlation ID. All named helpers except `noContent` also have an overload omitting that ID.

```apex
Object data = new List<String>{ 'first', 'second' };
String requestId = 'example-request';
ApiWriter.success(new RestResponse(), data, requestId);                 // 200
ApiWriter.created(new RestResponse(), data, requestId);                 // 201
ApiWriter.accepted(new RestResponse(), data, requestId);                // 202
ApiWriter.noContent(new RestResponse());                               // 204
ApiWriter.badRequest(new RestResponse(), 'Invalid input.', requestId);  // 400
ApiWriter.unauthorized(new RestResponse(), 'Authentication required.', requestId); // 401
ApiWriter.forbidden(new RestResponse(), 'Access denied.', requestId);   // 403
ApiWriter.notFound(new RestResponse(), 'Resource not found.', requestId); // 404
ApiWriter.conflict(new RestResponse(), 'Refresh the resource.', requestId); // 409
ApiWriter.serviceUnavailable(new RestResponse(), 'Try again later.', requestId); // 503
ApiWriter.internalError(new RestResponse(), requestId);                 // Safe 500
ApiWriter.failed(new RestResponse(), 412,
    new ApiError('STALE_VERSION', 'Refresh the resource.'), requestId);

// Original explicit-status success overload remains available.
ApiWriter.success(new RestResponse(), 206, data, requestId);
Assert.isTrue(ApiWriter.supports(206));
Assert.isFalse(ApiWriter.supports(429)); // Apex REST has a limited status set.

// Envelope factories do not write HTTP status or mutate RestContext.
ApiResponse success = ApiResponseFactory.success(data, requestId);
ApiResponse failed = ApiResponseFactory.failed('INVALID_INPUT', 'Invalid input.', requestId);
ApiResponse internal = ApiResponseFactory.internalError(requestId);
ApiWriter.write(new RestResponse(), 200, success);
ApiWriter.write(new RestResponse(), 400, failed);
ApiWriter.write(new RestResponse(), 500, internal);

// 304 is bodyless and uses a failure envelope because it is not a 2xx status.
ApiWriter.write(new RestResponse(), 304,
    ApiResponseFactory.failed('NOT_MODIFIED', 'Resource unchanged.', requestId));
```

For overloads without correlation, for example `ApiWriter.created(target, data)`, `ApiWriter.notFound(target, message)`, `ApiWriter.failed(target, 412, error)`, and `ApiWriter.internalError(target)`, the envelope request ID is null. Public messages must be deliberately safe; use the exception handler for unexpected failures. Set application-specific `Location` or `WWW-Authenticate` headers directly on the response before writing.

## Endpoint boundary

This fragment belongs inside an application-owned `@RestResource` class. It is not a complete deployable endpoint. Authentication, authorization, schema validation, bulk business processing, and transaction rollback belong to that application.

```apex
@HttpPost
global static void doPost() {
    String requestId = 'application-owned-correlation';
    try {
        List<String> values = (List<String>) ApiRequestReader.readAs(
            RestContext.request, List<String>.class);
        if (values == null || values.isEmpty()) {
            throw ApiException.create(400, 'EMPTY_INPUT', 'Supply at least one item.');
        }
        // Validate/process the entire collection in an application service.
        ApiWriter.success(RestContext.response, values, requestId);
    } catch (Exception failure) {
        ApiGlobalExceptionHandler.handle(RestContext.response, failure, requestId);
    }
}
```

Use a void REST method to avoid double serialization. The toolkit does not expose a route or install an exception interceptor. A safe typed error preserves its supported 4xx/5xx status/code/message; an unexpected exception becomes `500 / INTERNAL_ERROR`. Catching an exception does not roll back earlier DML.

For consumers that need only an envelope:

```apex
ApiResponse safe = ApiGlobalExceptionHandler.toResponse(
    ApiException.create(409, 'STALE_VERSION', 'Refresh the resource.'), requestId);
```

## Transport injection

The default client uses `ApiHttpTransport`, which calls native `Http.send`. These two forms are equivalent:

```apex
ApiHttpClient defaultClient = new ApiHttpClient();
ApiHttpClient explicitClient = new ApiHttpClient(new ApiHttpTransport());
```

An application transport implements `IApiTransport.send(HttpRequest)` and can delegate to the native adapter. This optional class illustrates the contract; create its metadata companion if you choose to install it:

```apex
public with sharing class PartnerTransport implements IApiTransport {
    public HttpResponse send(HttpRequest request) {
        // Application-owned instrumentation may surround execution; never log secrets.
        return new ApiHttpTransport().send(request);
    }
}
```

Supply it with `new ApiHttpClient(new PartnerTransport())`. Use platform `HttpCalloutMock` for native callout tests or inject an in-memory `IApiTransport` fixture as shown in `ApiBodyFormatterTest`. Custom production transports must preserve one native callout per request for count budgeting. `CalloutException` maps to `CALLOUT_FAILED`; programming exceptions propagate. No automatic retries or asynchronous scheduling occur.

## Formatter extension

JSON is the only production implementation. This uses all formatter operations directly:

```apex
IApiBodyFormatter formatter = new ApiJsonFormatter();
Assert.areEqual('application/json; charset=UTF-8', formatter.getContentType());
Assert.isTrue(formatter.supports('application/vnd.partner+json; charset=UTF-8'));
String text = formatter.encode(new List<String>{ 'ready' });
Object untyped = formatter.decode(text, null);
List<String> typed = (List<String>) formatter.decode(text, List<String>.class);
```

To add a format later, implement `getContentType`, `supports`, `encode(Object)`, and `decode(String, System.Type)` on `IApiBodyFormatter`. Keep implementations free of SOQL, DML, callouts, and input mutation. `ApiBodyFormatterTest` contains a sentinel formatter proving substitution; it is not a production format.

Select an application-owned formatter explicitly at each boundary:

```apex
// formatter is an IApiBodyFormatter instance chosen by trusted application code.
request.formatter = formatter;
request.payload = values;
request.body = null;
HttpRequest prepared = ApiRequestBuilder.build(request);
Object inbound = ApiRequestReader.read(restRequest, formatter);
Object typedInbound = ApiRequestReader.readAs(restRequest, List<String>.class, formatter);
Object upstream = outcome.read(formatter);
Object typedUpstream = outcome.readAs(List<String>.class, formatter);
ApiWriter.write(restResponse, 200, ApiResponseFactory.success(values, requestId), formatter);
```

This is a wiring fragment; `request`, `restRequest`, `outcome`, and `restResponse` are the corresponding toolkit/native objects from the scripts. The writer formats the complete `ApiResponse` envelope. Raw requests instead set `body`, clear `payload`/`formatter`, and supply Content-Type. An explicit Content-Type must be supported by the selected formatter. The reader checks Content-Type; upstream result decoding uses the formatter explicitly chosen by the caller.

Named response helpers and `ApiGlobalExceptionHandler` use JSON. When implementing a non-JSON endpoint later, write its error envelopes explicitly with the same formatter and an application-selected safe status; `toResponse` produces only the envelope, not a status. There is no automatic Accept negotiation, global registry, SOAP protocol implementation, or binary/multipart support.

## Errors and limits

| Situation | Behavior |
| --- | --- |
| Invalid request, body/formatter conflict, encoding failure | Whole-batch `ApiException` before any new callout |
| Batch exceeds remaining callout slots | `503 / CALLOUT_BUDGET_EXCEEDED`; split work into separate transactions |
| Non-2xx upstream status | Ordered result with `HTTP_ERROR`, status and raw body retained |
| Callout failure | Ordered result with sanitized `CALLOUT_FAILED`; later requests still attempted |
| Invalid JSON/custom inbound body | `400 / INVALID_JSON` or `INVALID_BODY` |
| Missing/unsupported inbound Content-Type | `415 / UNSUPPORTED_MEDIA_TYPE` |
| Invalid upstream body during explicit parsing | `500 / INVALID_UPSTREAM_JSON` or `INVALID_UPSTREAM_BODY` |
| Missing formatter/type configuration | Typed error; see reader/result contracts |
| Invalid writer status/envelope or formatting failure | `500 / INVALID_RESPONSE`; target unchanged |

Prefer one partner bulk endpoint for 251 business items, as constructed in `http-request-building.apex`. `sendAll` does not turn 251 requests into one callout or split them into jobs. At most the transaction's remaining callout slots are available; cumulative callout time, heap, and CPU also apply. Complete callouts before DML. Production adapters need their own credential/partner smoke test. See [HTTP contracts](../../docs/http-integration.md) and [verification results](../../docs/http-verification.md).
