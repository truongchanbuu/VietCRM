# Repository conventions

This is salesforce-develop-kit, a reusable Salesforce development kit. Read README.md and config/modules.json before changing module boundaries.

- Keep deployable source in force-app. Use classes/<module>/<role>; keep metadata companions and globally unique Apex names.
- This branch contains only the query module. Declare new dependencies explicitly; query must not reference other feature modules or examples.
- Use the pinned Salesforce skills under .agents/skills for Apex authoring, tests, metadata operations, and Code Analyzer. Treat examples in skills as templates, not deployable code.
- Default to explicit sharing, user-mode queries/DML, validated identifiers, and bound values. Document any intentional system-mode boundary.
- No SOQL/DML in production loops. Test bulk behavior, errors, access denial, and continuation correctness. Never use SeeAllData=true.
- Before finishing code changes, run npm test, npm run analyze:core, and npm run validate:core -- --target-org <development alias>. Validate local source and tests together.
- Keep retrieved org changes and local changes recoverable before synchronization. Retrieve into an isolated project and review differences before overlaying source.
- Other modules and historical CRM source are preserved on feature/developer-kit-foundation. Do not add them to this query-only feature.
- Do not include auth files, credentials, generated analyzer reports, or .local-state recovery snapshots in commits.

- Develop each feature on a separate feature/<module>-<purpose> branch from main. Keep its implementation, metadata, tests, examples, and docs together. Merge completed, validated features through a pull request into main; do not develop features directly on main. See CONTRIBUTING.md.
