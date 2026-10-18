# Opt-in trigger example

`AccountToolkitExample.trigger` invokes `AccountTriggerHandler.run()`. The handler casts native inputs, trims names before insert, records the previous name only when the name changes on update, and rejects names beginning with `REJECT:` using `addError()`. These are sample business rules; adapt them before use. Nothing here is installed by the core package.

Use one trigger per object. If an Account trigger already exists, incorporate the callback into that trigger and explicitly order your service calls. Keep rules idempotent and database operations in consuming services bulkified and in user mode. See the [toolkit contracts](../../docs/trigger-toolkit.md).

## Check-only integration validation

Create an isolated Salesforce project by copying `sfdx-project.json` and the candidate `force-app` directory. Copy the three Account Apex files and their metadata companions from this directory into that project's `force-app/main/default/classes` and `triggers` folders. Also copy `integration/` classes and its Contact trigger into the same standard folders. Run from the temporary project:

```sh
sf project deploy start --dry-run --target-org dev --source-dir force-app \
  --test-level RunLocalTests --wait 10 --json
```

For a dedicated validation org, `RunLocalTests` includes the candidate core tests and both integration test classes; it also runs existing unmanaged org tests. The repository's `npm run validate:core -- --target-org dev` separately selects all candidate core test classes without installing these examples. A check-only deployment uploads candidate implementation and tests together, executes tests, and rolls back metadata and test data.

`AccountTriggerIntegrationTest` covers insert/update/delete/undelete with 251 records, repeated updates, unchanged values, and partial-success insert/update errors. `integration/TriggerToolkitNativeTest` uses a validation-only Contact trigger and handler to assert all seven native events, concrete collection casts, batch splitting, native edits, and read-only restrictions. The Contact probe is instrumentation for a temporary validation project and must not be installed as an application trigger. Test-only undelete uses Apex's native operation, which has no user-mode keyword; its records are created by the same test.
