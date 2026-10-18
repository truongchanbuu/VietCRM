# HTTP toolkit verification

Validated on 2026-10-18, branch `feature/http`, against development org alias `dev`.

- `npm test`: passed, two independent modules and 51 Apex classes/interfaces; formatting passed.
- `npm run analyze:core`: passed the critical/high gate. Complete core: 0 critical, 0 high, 159 moderate, 255 low. HTTP-only: 0 critical/high, 99 moderate, 132 low. No severity overrides or suppressions were added.
- `npm run validate:core -- --target-org dev`: succeeded, check-only job `0Afbm00000k12yBCAQ`. All 51 local classes/interfaces compiled; 163 tests passed (115 HTTP and 48 query), 0 failures, 0 coverage warnings. No metadata persisted.
- HTTP aggregate executable-line coverage: 540/541 (99.82%). Statement coverage is not branch coverage and does not prove every integration environment.

| HTTP class | Covered lines | Coverage |
| --- | --- | --- |
| ApiCalloutResult | 41/41 | 100.00% |
| ApiError | 3/3 | 100.00% |
| ApiException | 5/5 | 100.00% |
| ApiGlobalExceptionHandler | 21/21 | 100.00% |
| ApiHttpClient | 76/76 | 100.00% |
| ApiHttpTransport | 2/2 | 100.00% |
| ApiJsonFormatter | 14/14 | 100.00% |
| ApiRequest | 4/4 | 100.00% |
| ApiRequestBuilder | 146/147 | 99.32% |
| ApiRequestReader | 69/69 | 100.00% |
| ApiResponse | 0/0 | No executable lines |
| ApiResponseFactory | 19/19 | 100.00% |
| ApiWriter | 140/140 | 100.00% |

## Exercised behavior

- Client-owned Named Credential/HTTPS service bases, relative paths, prefix/slash joining, root requests, per-request headers/query/payload/correlation, reuse without DTO mutation, and invalid batch configuration rejected before callouts. Legacy full-endpoint clients remain covered.

- Common GET/POST/PUT/PATCH/DELETE shortcuts without a manually constructed request, injected and native transports, JSON null payloads, 251-item payloads, HTTP/callout failures, invalid endpoints, and exhausted callout budget.

- Custom test-only formatter through outbound requests/results and REST readers/writers, typed decoding, encoding/decoding failure sanitization, unsupported media, missing formatters, and no target mutation on encoding failure.
- JSON formatter typed/untyped round trips with 251 values and no SOQL/DML; all legacy JSON tests retained.

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

PMD's IfStmtsMustUseBraces and IfElseStmtsMustUseBraces recommendations flag short guards allowed by the repository standards. These remain visible in the moderate findings; no rule was disabled or severity changed. The critical/high gate and all regression tests passed.

## Common response helpers

ApiResponseFactory and named ApiWriter helpers are covered by 38 new tests: every named success/error status, correlation and no-correlation overloads, custom failures, invalid statuses/contracts rejected before response mutation, bodyless noContent, fresh error envelopes, and 251-item collection preservation. Existing handler tests still verify safe unexpected-error handling and compatibility with the original writer API. ApiResponseFactory and all named writer helpers have full executable-line coverage in this run.

The CLI lost its polling connection near the end of validation. Reading the same job with `sf project deploy report` confirmed Succeeded, 140 tests and no failures or coverage warnings; no duplicate deployment was submitted. PMD also reports the larger public method count for ApiWriter, reflecting the explicit status helpers and their no-correlation overloads. No rule was suppressed or disabled.

## Usage examples

All seven HTTP scripts were compiled and executed as temporary Apex test methods in an isolated copy of the current project, with `HttpCalloutMock` replacing native HTTP execution. Check-only job `0Afbm00000k18M2CAI` passed all 170 tests: 163 core tests and seven usage scripts. The temporary wrapper is not production source. No metadata or partner requests were persisted/executed.

All HTTP `.apex` examples pass the Apex anonymous formatter/parser. Explicitly running `http-callout`, `http-bulk-callout`, or `http-verb-shortcuts` outside the mocked validation makes real partner requests and requires a development endpoint and Named Credential. The verb script includes POST/PUT/PATCH/DELETE operations.
