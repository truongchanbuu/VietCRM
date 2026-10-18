# Usage examples

## HTTP integration

See the [HTTP examples guide](http/README.md) for the full feature map, runnable local scripts, real-callout scripts, every response helper, endpoint exception handling, and formatter/transport extension contracts.

## Query pagination

Deploy the query module to a development org, then run the read-only Account example explicitly:

```sh
sf apex run --file examples/apex/query-pagination.apex --target-org dev
```

It demonstrates keyset pagination using standard Account fields. No custom objects or business application metadata are required. See [pagination contracts](../docs/db-query-pagination.md) for OFFSET, PAGE_CURSOR, QueryLocator, typed filters, and custom strategies.
