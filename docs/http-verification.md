# HTTP toolkit verification

Validated on 2026-10-18, branch `feature/http`, against development org alias `dev`.

- `npm test`: passed, two independent modules and 43 Apex classes/interfaces; formatting passed.
- `npm run analyze:core`: passed the critical/high gate. Complete core: 0 critical, 0 high, 108 moderate, 185 low. HTTP-only: 0 critical/high, 48 moderate, 62 low. No severity overrides or suppressions were added.
- `npm run validate:core -- --target-org dev`: succeeded, check-only job `0Afbm00000k151ZCAQ`. All 43 local components compiled; 102 tests passed (54 HTTP and 48 query), 0 failures, 0 coverage warnings. No metadata persisted.
- HTTP aggregate executable-line coverage: 302/303 (99.67%). Statement coverage is not branch coverage and does not prove every integration environment.

| HTTP class                | Covered lines | Coverage            |
| ------------------------- | ------------- | ------------------- |
| ApiCalloutResult          | 16/16         | 100.00%             |
| ApiError                  | 3/3           | 100.00%             |
| ApiException              | 5/5           | 100.00%             |
| ApiGlobalExceptionHandler | 25/25         | 100.00%             |
| ApiHttpClient             | 50/50         | 100.00%             |
| ApiHttpTransport          | 2/2           | 100.00%             |
| ApiRequest                | 4/4           | 100.00%             |
| ApiRequestBuilder         | 85/86         | 98.84%              |
| ApiRequestReader          | 54/54         | 100.00%             |
| ApiResponse               | 0/0           | No executable lines |
| ApiWriter                 | 58/58         | 100.00%             |

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

## Engineering standards styling pass

HTTP source and tests now follow AGENTS.md Engineering & Coding Standards: one blank line between logical phases and members, formatter-compatible short guards, explicit branches instead of nested ternaries, flatter exception flow, and descriptive request fixture names. Public APIs, payloads, test cases and assertion order were retained. This pass introduces no new abstractions or formatter configuration.

PMD's IfStmtsMustUseBraces and IfElseStmtsMustUseBraces recommendations flag the eight short guards allowed by the repository standards. These remain visible in the moderate findings; no rule was disabled or severity changed. The critical/high gate and all 102 regression tests passed.
