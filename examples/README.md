# Query pagination example

Deploy the query module to a development org, then run the read-only Account example explicitly:

```sh
sf apex run --file examples/apex/query-pagination.apex --target-org dev
```

It demonstrates keyset pagination using standard Account fields. No custom objects or business application metadata are required. See `docs/db-query-pagination.md` for OFFSET, PAGE_CURSOR, and QueryLocator usage.

`http-callout.apex` demonstrates a Named Credential request. It makes a real outbound request when run explicitly; configure the credential and review the endpoint before running. The inbound endpoint pattern is documented in `docs/http-integration.md` and is not deployed automatically.
