# HTTP toolkit verification

Validated on 2026-10-18, branch `feature/http`, against development org alias `dev`.

- `npm test`: passed, two independent modules and 43 Apex classes/interfaces; formatting passed.
- `npm run analyze:core`: passed the critical/high gate. Complete core: 0 critical, 0 high, 93 moderate, 185 low. HTTP-only: 0 critical/high, 33 moderate, 62 low. No severity overrides or suppressions were added.
- `npm run validate:core -- --target-org dev`: succeeded, check-only job `0Afbm00000k0fRNCAY`. All 43 local components compiled; 102 tests passed (54 HTTP and 48 query), 0 failures, 0 coverage warnings. No metadata persisted.
- HTTP aggregate executable-line coverage: 300/301 (99.67%). Statement coverage is not branch coverage and does not prove every integration environment.

| HTTP class                | Covered lines | Coverage            |
| ------------------------- | ------------- | ------------------- |
| ApiCalloutResult          | 16/16         | 100.00%             |
| ApiError                  | 3/3           | 100.00%             |
| ApiException              | 5/5           | 100.00%             |
| ApiGlobalExceptionHandler | 24/24         | 100.00%             |
| ApiHttpClient             | 50/50         | 100.00%             |
| ApiHttpTransport          | 2/2           | 100.00%             |
| ApiRequest                | 4/4           | 100.00%             |
| ApiRequestBuilder         | 83/84         | 98.81%              |
| ApiRequestReader          | 54/54         | 100.00%             |
| ApiResponse               | 0/0           | No executable lines |
| ApiWriter                 | 59/59         | 100.00%             |

## Exercised behavior

- 251 business records sent in one mocked bulk HTTP request; 251 items serialized in an inbound REST response.
- 100 mocked callouts in one transaction, ordered outcomes, and no toolkit SOQL/DML consumption.
- A 251-callout batch and a batch exceeding an already-partially-consumed budget rejected before new network side effects.
- Whole-batch preflight catches a malformed later request before the first request is sent.
- 2xx/204, 401, 429, 503, redirects, thrown callout failures, missing native responses, empty/null inputs and injected transports.
- HTTPS/Named Credential construction, supported methods, query encoding, header normalization, invalid/duplicate/newline/managed headers, credential-bearing URLs and timeout boundaries.
- Lazy upstream JSON parsing, invalid JSON, invalid UTF-8, typed inbound DTO parsing, vendor media types, Content-Type casing/charset and missing/unsupported media types.
- Explicit safe application errors, sanitized unexpected errors, invalid response status/envelope, correlation IDs and bodyless 204 responses.

## Remaining findings and limits

Most HTTP analyzer findings are test runAs recommendations and helper-based assertion detection. Assertions run in shared test helpers; HTTP code has no database/security-user operations. Production findings cover complexity, API documentation style and parameter count. The report remains available locally in ignored artifacts; no zero-findings claim is made.

All HTTP transport tests use HttpCalloutMock or an injected fake. Real partner connectivity, Named Credential principal access, remote authentication and partner-specific schemas were not exercised. Apex REST handler helpers were tested directly; no public endpoint is installed. This validation used an existing development org, not a fresh scratch org.

Callout count is preflighted. Cumulative callout time, CPU, heap, response/request size and uncommitted-work rules remain platform/application constraints. Large per-record integrations need separate application-owned transactions; retries, queueing, durable results, binary/multipart streaming and circuit breakers are outside this initial module. API and transaction ownership are described in [HTTP integration contracts](http-integration.md).
