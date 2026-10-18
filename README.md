# salesforce-develop-kit

A reusable Salesforce developer kit for common development tasks, with extensible Apex modules, tests, examples, and development tooling. The deployable core contains independent database query/pagination and HTTP integration modules. Logging, feature flags, and historical CRM code are preserved on `feature/developer-kit-foundation`.

## Structure

```text
force-app/main/default/
  classes/
    query/{services,builders,dto,exceptions,factories,interfaces,selectors,strategies,tests}/
    http/{services,builders,dto,exceptions,factories,interfaces,handlers,strategies,tests}/
examples/apex/            # Opt-in usage examples
.agents/skills/           # Pinned Salesforce-maintained development skills
.codex/config.toml        # Optional local DX MCP connection for dev
scripts/quality/         # Module and deployment validation
```

Apex names are global within the package: folders organize ownership, not namespaces. Keep class names unique and include each class's metadata companion. `config/modules.json` declares module dependencies and object ownership. Both modules have no dependencies on other application modules. HTTP clients own their service base (for example, `new ApiHttpClient('callout:CRM_API')`); operations supply relative paths such as `client.get('/v1/accounts')`.

## Setup and checks

Use Node 22 LTS, Salesforce CLI, Java 21 for Code Analyzer, and an authenticated development org. The project retains API version 67.0.

```sh
npm ci
npm test
sf plugins install @salesforce/plugin-code-analyzer@5.16.0
npm run analyze:core
npm run validate:core -- --target-org dev
```

`npm test` checks structure, undeclared dependencies, archive references, metadata companions, and formatting. Apex executes on Salesforce; `validate:core` uploads **all local core source and tests** in a check-only deployment, discovers test classes automatically, and enforces Salesforce coverage requirements. It does not persist metadata. A successful local check alone is not an Apex test pass.

For an intentional deployment after validation:

```sh
sf project deploy start --source-dir force-app --target-org dev --test-level RunLocalTests --wait 10
```

RunLocalTests also includes existing unmanaged tests in the target org. Use a clean scratch org or dedicated sandbox to validate installation independently from unrelated org applications. Moving files here does not delete old components from an existing org.

## Modules

| Module | Entry points                                                                          | Extension points                                         |
| ------ | ------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| Query  | `DbQueryService.execute`, `queryLocator`, `fetchPage`                                 | `IDbPageStrategy` + caller-owned `DbPageStrategyFactory` |
| HTTP   | `ApiHttpClient.get/post/put/patch/deleteRequest/sendAll`, `ApiRequestReader`, `ApiWriter`, `ApiGlobalExceptionHandler` | `IApiTransport` and explicit `IApiBodyFormatter`                     |

See [HTTP integration](docs/http-integration.md), [module contracts](docs/modules.md), [pagination](docs/db-query-pagination.md), [AI tooling](docs/salesforce-ai-tooling.md), and [examples](examples/README.md).

## Quality and security

Use explicit sharing and user-mode queries for application data; bind values and validate identifiers. Keep DML/SOQL out of loops, keep triggers thin, and test bulk, invalid input, pagination boundaries, and access denial.

CI runs structure/format checks and PMD Recommended rules, failing on severity 1 or 2. Moderate/low findings remain visible in the report, not silently treated as passes. The manual CI Apex job requires environment `salesforce-validation` with secret `SF_AUTH_URL` for a dedicated validation org; it performs only a dry-run. No production credentials belong in Git.

## Source synchronization

The query source was synchronized from `dev` on 2026-10-14. The broader source recovery and historical CRM files are preserved on `feature/developer-kit-foundation`. Local recovery snapshots remain ignored under `.local-state/`. Removing repository files does not delete org metadata.

## Feature development

Develop each feature on its own `feature/<module>-<purpose>` branch, created from current `main`. Keep implementation, metadata, tests, examples, and documentation together in that branch. Open a pull request to `main` only when the feature is complete and validated; `main` contains the final integrated version. Use `fix/<module>-<issue>` for fixes.

The broader module extraction is preserved on `feature/developer-kit-foundation`; new HTTP development is maintained on `feature/http`. Future features follow the independent branch workflow in [CONTRIBUTING.md](CONTRIBUTING.md). The local workspace directory and GitHub repository URL are separate from the project metadata name.
