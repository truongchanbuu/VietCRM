# Contributing to salesforce-develop-kit

Build reusable modules for common Salesforce development tasks. Keep business-specific applications outside the deployable core.

## One branch per feature

1. Start from current `main`: `git switch main` and `git pull --ff-only origin main`.
2. Create `feature/<module>-<purpose>`, for example `feature/query-composite-keyset`. Use `fix/<module>-<issue>` for a correction.
3. Implement the feature with its metadata, tests, usage examples, and documentation on that branch. Keep unrelated features in separate branches.
4. Run the required checks below against the exact source proposed for merge.
5. Push the branch and open a pull request targeting `main`. Describe behavior, extension points, validation evidence, and limitations.
6. Merge the completed feature after review and successful checks. Use a squash merge for a coherent feature commit. Delete the feature branch after merge.

`main` is the final integrated version. An in-progress branch or a partial implementation is not a released feature. Deployment is a separate operation from merging.

## Module structure

Put Apex in `force-app/main/default/classes/<module>/<role>/`, using roles such as `services`, `domains`, `dto`, `interfaces`, `providers`, `strategies`, `selectors`, `exceptions`, and `tests` as needed. Each feature belongs to its owning module; avoid shared top-level service or DTO folders. Include every metadata companion and keep Apex names globally unique.

Salesforce objects, permission sets, and triggers retain their standard metadata folders. Declare module object ownership and dependencies in `config/modules.json`. Core modules cannot depend on `archive` or `examples`. Add usage examples under `examples`, and preserve unrelated features on their own branches.

## Required checks

```sh
npm ci
npm test
npm run analyze:core
npm run validate:core -- --target-org dev
```

The Apex validation submits local production source and tests together as a dry-run. Include the validation job ID, test result, and coverage warnings in the pull request. Report remaining analyzer findings; severity 1 or 2 fails the gate. Test bulk behavior, error paths, access denial, and pagination continuation where applicable.

Use the official pinned Salesforce skills under `.agents/skills`. Follow `AGENTS.md` for security and synchronization rules. Never commit credentials, recovery snapshots, or generated analyzer reports.

## GitHub configuration

Configure a ruleset for `main` to require pull requests, review, and the `source` job from the Core quality workflow. Configure the `salesforce-validation` environment and its `SF_AUTH_URL` secret, then run the manual Apex job on the candidate branch before merge. Repository rules and environment secrets require GitHub access; local workflow files alone do not enforce these settings. Fork pull requests must not receive org credentials automatically.

The project metadata is named `salesforce-develop-kit`. Renaming the hosted GitHub repository and updating `origin` require access to that repository; they are separate from the local project rename.
