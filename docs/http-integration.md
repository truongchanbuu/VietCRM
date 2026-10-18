# HTTP Integration Toolkit

The independent `http` module provides outbound HTTP orchestration and explicit inbound Apex REST handlers. It depends on no custom metadata, business objects, or other core modules. It exposes no REST route by itself and performs no SOQL, DML, logging, retries, or async job scheduling.

## Layout and contracts

| Role       | Classes                                                      | Purpose                                                   |
| ---------- | ------------------------------------------------------------ | --------------------------------------------------------- |
| DTOs       | `ApiRequest`, `ApiCalloutResult`                             | Outbound request and ordered raw outcome                  |
| DTOs       | `ApiResponse`, `ApiError`                                    | Public response envelope and safe error contract              |
| Exceptions | `ApiException`                                               | Explicit application status/code/public message           |
| Factories  | `ApiResponseFactory`                                         | Fresh success/error envelopes independent of REST writing |
| Builders   | `ApiRequestBuilder`                                          | Validate and build native requests before sending         |
| Interfaces | `IApiTransport`, `IApiBodyFormatter`                             | Injectable transport and text representation                            |
| Strategies | `ApiJsonFormatter` | Default JSON text encoding and decoding |
| Services   | `ApiHttpClient`, `ApiHttpTransport`                          | Bulk orchestration and platform callouts                  |
| Handlers   | `ApiRequestReader`, `ApiWriter`, `ApiGlobalExceptionHandler` | Inbound JSON, response serialization, safe error mapping  |

`ApiRequest` defaults to GET, a 10,000 ms timeout, and empty header/query maps. It accepts HTTPS endpoints or `callout:Named_Credential/path`; prefer Named Credentials and External Credentials for authentication. Header and query values belong to trusted Apex configuration, not arbitrary public request input. An application accepting external destinations must apply its own destination allowlist.

The builder supports GET, HEAD, POST, PUT, PATCH, DELETE, and OPTIONS. It rejects invalid endpoints, whitespace/fragments, URL user-info credentials, unsupported methods, GET/HEAD bodies, timeouts outside 1–120,000 ms, invalid/newline/duplicate headers, and platform-managed headers. Query values are URL encoded; names are sorted for deterministic construction. Supply Content-Type explicitly for raw POST/PUT/PATCH bodies; formatter payloads default to their formatter’s Content-Type; the toolkit does not assume all outbound bodies are JSON. Authentication remains with the Named Credential configuration or a developer-owned transport.

## Outbound usage

```apex
ApiHttpClient client = new ApiHttpClient();
ApiCalloutResult outcome = client.post('callout:Partner_API/v1/bulk', items);
if (outcome.isSuccess()) {
    Object acknowledgment = outcome.readJson();
} else {
    // Apply application-specific persistence, monitoring or retry policy.
}
```

`get(endpoint)`, `post(endpoint, payload)`, `put(endpoint, payload)`, `patch(endpoint, payload)`, and `deleteRequest(endpoint)` cover common calls. POST/PUT/PATCH use `ApiJsonFormatter`; null payloads encode as JSON null. String payloads encode as JSON strings; pass objects directly instead of pre-serializing. GET/DELETE have no body. Apex reserves `delete`, so the DELETE helper is named `deleteRequest`. These helpers delegate to the same validated `send`/`sendAll` path; no manual request builder call is required.

For custom headers, query parameters, timeout, correlation, raw bodies, or a selected formatter, use the full configuration path:

```apex
ApiRequest request = new ApiRequest();
request.endpoint = 'callout:Partner_API/v1/bulk';
request.method = 'POST';
request.requestId = 'application-correlation-id';
request.headers.put('X-Request-Id', request.requestId);
request.timeoutMillis = 5000;
request.formatter = new ApiJsonFormatter();
request.payload = items;
ApiCalloutResult outcome = new ApiHttpClient().send(request);
```

The Named Credential and its access assignments must already exist in the target org. No credential material is stored in source. `requestId` is copied into the result; add an outbound correlation header explicitly if the partner requires one.

`sendAll(List<ApiRequest>)` returns exactly one outcome per input, in order. It checks `Limits.getLimitCallouts() - Limits.getCallouts()` and validates every request before the first network side effect. Null lists are rejected; empty lists return empty results. Invalid configuration or insufficient slots raises `ApiException`; these are whole-batch preflight failures. Runtime callout failures become `CALLOUT_FAILED` outcomes, while non-2xx HTTP responses retain the status/body/headers and receive `HTTP_ERROR`. Results after a failed callout are still attempted. Header names in results are lowercase; JSON bodies are parsed lazily with `readJson`, which returns null for empty bodies and raises a typed error for malformed JSON.

Raw upstream bodies and headers can contain secrets and are for trusted server-side application code. Do not pass an entire `ApiCalloutResult` to a public writer without choosing the safe fields. Transport failure messages are intentionally generic. An injected transport can integrate an application's diagnostic policy without making the toolkit depend on a logger. Unexpected programming exceptions from an injected transport propagate; native callout failures are captured. The client does not retry, follow an application retry policy, or replay requests implicitly; use explicit idempotency keys and a durable application-owned retry process where needed.

## Bulk and governor limits

Prefer a partner's bulk endpoint: 251 business records can be serialized once and sent in **one callout**. The tests exercise that pattern. If each record requires a separate callout, 251 requests cannot run in one Salesforce transaction. Use application-owned Batch Apex or Queueable jobs with `Database.AllowsCallouts` and persist outcomes per chunk. `sendAll` rejects an oversized batch before sending any callouts.

The platform permits up to 100 callouts per transaction and a cumulative 120 seconds of callout timeout. Prior work in the same transaction shares those limits. The toolkit preflights the count, not the cumulative elapsed time: there is no reliable remaining-callout-time governor getter, and it cannot account for callouts outside the toolkit. A per-request timeout of 120 seconds is not a promise that multiple such requests will complete. Choose batch sizes, payload sizes and timeouts according to partner latency and remaining heap/CPU. Responses are retained in memory; the client is not a streaming API. Binary/multipart bodies, automatic chunking, retries, circuit breakers and durable delivery are outside this initial module.

Complete callouts before DML. Apex can reject callouts after uncommitted work; the toolkit does not rearrange application transactions, roll back DML, or catch uncatchable governor exceptions. Default `IApiTransport` consumes one callout per request; custom transports must preserve that contract for the preflight count to remain meaningful.

## Inbound REST usage

Use **void** Apex REST methods when writing `RestResponse` directly to avoid automatic double serialization. This is an example, not a deployed endpoint:

```apex
@HttpPost
global static void doPost() {
    try {
        List<Object> input = (List<Object>) ApiRequestReader.readJson(RestContext.request);
        // Validate authorization/schema and process the collection in a bulk service.
        ApiWriter.success(RestContext.response, results, requestId);
    } catch (Exception failure) {
        ApiGlobalExceptionHandler.handle(RestContext.response, failure, requestId);
    }
}
```

Apex has no installable global exception interceptor. Each endpoint must call this handler at its outer boundary. Applications own sharing, CRUD/FLS, user-mode data access, request authorization, schema/business validation, transaction savepoints/rollback and diagnostics. Catching an exception does not undo earlier application DML.

`ApiRequestReader.readJson` accepts application/json and application/*+json (including charset parameters). Header names and media types are case-insensitive. Missing/empty bodies or malformed JSON are typed 400 errors; missing/unsupported Content-Type is 415. `readAs(request, MyDto.class)` supports typed DTOs and tolerates additional JSON fields for evolution. Parsed JSON null or an incorrectly shaped payload must be checked by the application.

`ApiWriter.success` writes `{success,data,error,requestId}`, with JSON escaping and no-store caching. It serializes the whole collection once, uses Apex REST's supported status set, and leaves 204/304 responses bodyless. Custom headers such as Location can be set directly on the response. Unsupported statuses and contradictory envelopes are rejected before mutating the target. Apex REST does not support every standard HTTP status: upstream 429 is retained by the outbound client, but a typed inbound error with an unsupported status falls back to a safe 500.

`ApiException.create(409, 'CONFLICT', 'Version conflict.')` marks an explicitly safe application error. Only valid typed errors expose their chosen code/message. Other exceptions, null exceptions, and malformed typed errors become 500 / INTERNAL_ERROR, with no stack trace or raw exception message. There is no automatic message redaction for intentionally public application errors; choose their text deliberately.

## Common response helpers

Named writer methods bind the status and standard error code so endpoint code does not repeat status literals or envelope setup. Supply `requestId` as the final optional overload; omit it when correlation is not needed. All calls use the same validated writer and preserve its JSON headers, no-store policy and bodyless-response rules.

| Helper                                             | Status            | Error code                    |
| -------------------------------------------------- | ----------------- | ----------------------------- |
| `success(target, data[, requestId])`               | 200               | —                             |
| `created(target, data[, requestId])`               | 201               | —                             |
| `accepted(target, data[, requestId])`              | 202               | —                             |
| `noContent(target)`                                | 204               | —                             |
| `badRequest(target, message[, requestId])`         | 400               | BAD_REQUEST                   |
| `unauthorized(target, message[, requestId])`       | 401               | UNAUTHORIZED                  |
| `forbidden(target, message[, requestId])`          | 403               | FORBIDDEN                     |
| `notFound(target, message[, requestId])`           | 404               | NOT_FOUND                     |
| `conflict(target, message[, requestId])`           | 409               | CONFLICT                      |
| `internalError(target[, requestId])`               | 500               | INTERNAL_ERROR                |
| `serviceUnavailable(target, message[, requestId])` | 503               | SERVICE_UNAVAILABLE           |
| `failed(target, status, error[, requestId])`       | Supported 4xx/5xx | Caller-supplied ApiError code |

Square brackets in the table mean an overload, not Apex optional-argument syntax.

```apex
ApiWriter.created(RestContext.response, createdRecords, requestId);
ApiWriter.notFound(RestContext.response, 'The requested resource was not found.');
ApiWriter.failed(RestContext.response, 412,
    new ApiError('STALE_VERSION', 'Refresh the resource.'), requestId);
ApiWriter.noContent(RestContext.response);
```

These are alternative endpoint outcomes, not sequential writes to the same response. Set any endpoint-specific Location or authentication headers on the target explicitly. `accepted` writes 202; application code owns actually accepting or queuing work.

For envelope-only consumers, use `ApiResponseFactory.success(data, requestId)`, `failed(code, message, requestId)`, or `internalError(requestId)`. Each call returns a fresh envelope. Error factories require a nonblank code and message; they carry no success data. The exception handler uses the same factories so default error contracts stay consistent. The envelope does not contain HTTP status: status belongs to the writer/transport.

`failed` rejects success statuses, unsupported Apex REST statuses, null errors and incomplete error contracts before changing the response. Public error messages are application-owned; pass unexpected exceptions to ApiGlobalExceptionHandler rather than forwarding raw diagnostic text. Existing `ApiWriter.success(target, statusCode, data, requestId)` and `write` APIs remain supported.

## Extending body formats

`IApiTransport` owns HTTP execution. `IApiBodyFormatter` owns a UTF-8 text representation through `getContentType`, `supports`, `encode`, and `decode`. `ApiJsonFormatter` is the only built-in formatter. Existing raw request bodies and JSON helpers remain supported; no SOAP/XML implementation or global formatter registry is installed.

```apex
ApiRequest request = new ApiRequest();
request.endpoint = 'callout:Partner_API/v1/bulk';
request.method = 'POST';
request.formatter = new ApiJsonFormatter();
request.payload = items;
ApiCalloutResult result = new ApiHttpClient().send(request);
List<MyDto> decoded = (List<MyDto>) result.readAs(List<MyDto>.class, request.formatter);
```

To add another text representation later, implement `IApiBodyFormatter` and pass the instance at the boundary:

```apex
Object input = ApiRequestReader.read(RestContext.request, formatter);
MyDto typed = (MyDto) ApiRequestReader.readAs(RestContext.request, MyDto.class, formatter);
ApiWriter.write(RestContext.response, 201,
    ApiResponseFactory.success(results, requestId), formatter);
Object upstream = result.read(formatter);
```

Here `formatter` is an application-supplied implementation. The writer passes the complete `ApiResponse` envelope to `encode`; the application formatter must represent that contract. Named writer helpers and `ApiGlobalExceptionHandler` continue to emit JSON. An endpoint selecting another representation must explicitly use `write(..., formatter)` for its own error envelopes too. The toolkit does not automatically negotiate Accept headers or select a format from upstream Content-Type.

Supply either `body` (raw text) or `formatter` plus `payload`. A payload without a formatter, a raw body combined with a formatter, unsupported Content-Type, or a formatter encoding failure rejects the entire outbound batch before any callout. Explicit compatible Content-Type headers are retained; otherwise the formatter supplies its default. GET/HEAD cannot carry formatter payloads. A formatter may encode null payloads but must return non-null text.

Implementations must be pure: no callouts, SOQL, DML, or payload mutation. Handle media types and parameters deliberately in `supports`; `decode` receives a null type for untyped parsing or the caller's explicit Apex type. Formatter exceptions are sanitized at encoding/decoding boundaries. Generic inbound decoding reports `400 / INVALID_BODY`; upstream decoding reports `500 / INVALID_UPSTREAM_BODY`. Legacy JSON helpers retain `INVALID_JSON` and `INVALID_UPSTREAM_JSON`. Missing formatters are configuration errors (`INVALID_FORMATTER`). Response encoding completes before the target is mutated, and 204/304 skip encoding.

This seam covers text serialization. Protocol behavior such as SOAP actions, operation envelopes, faults, authentication, or binary/multipart transfer requires an application adapter when implemented; a formatter alone does not provide those features. A test-only sentinel formatter proves substitution without adding another production format.

See the [HTTP examples guide](../examples/http/README.md) for runnable scripts and examples of every public feature.

## Validation

```sh
npm test
npm run analyze:core
npm run validate:core -- --target-org dev
```

See [HTTP verification](http-verification.md) for actual results. Mocked tests verify behavior without real network requests or deployed Named Credentials; the target application must smoke-test its actual credential/principal assignments and partner endpoint separately.

## Salesforce references

- [Execution governors and limits](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm)
- [Named Credentials for callouts](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts_named_credentials.htm)
- [HttpRequest reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httprequest.htm)
- [RestResponse reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restresponse.htm)
