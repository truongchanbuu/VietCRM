# Usage examples

## Trigger toolkit

See the opt-in [Account trigger and validation fixtures](trigger/README.md). These files stay outside `force-app`; copy them explicitly into an isolated development project with the candidate core to validate them.

## Logging

See the [logger adaptation guide](../docs/logging.md) and [usage example](logging/logger.apex). Logger Apex lives in `force-app` and assumes the consuming org already has the sample event, log object, and fields, or that developers have adapted the source to their own schema.

## HTTP integration

See the [HTTP examples guide](http/README.md) for the full feature map, runnable local scripts, real-callout scripts, every response helper, endpoint exception handling, and formatter/transport extension contracts.

## Query pagination

Deploy the query module to a development org, then run the read-only Account example explicitly:

```sh
sf apex run --file examples/apex/query-pagination.apex --target-org dev
```

It demonstrates keyset pagination using standard Account fields. No custom objects or business application metadata are required. See [pagination contracts](../docs/db-query-pagination.md) for OFFSET, PAGE_CURSOR, QueryLocator, typed filters, and custom strategies.
