# Repository conventions

This is salesforce-develop-kit, a reusable Salesforce development kit. Read README.md and config/modules.json before changing module boundaries.

- Keep deployable source in force-app. Use classes/<module>/<role>; keep metadata companions and globally unique Apex names.
- Query and HTTP are independent modules. Declare new dependencies explicitly; neither may reference other modules or examples without a declared dependency.
- Use the pinned Salesforce skills under .agents/skills for Apex authoring, tests, metadata operations, and Code Analyzer. Treat examples in skills as templates, not deployable code.
- Default to explicit sharing, user-mode queries/DML, validated identifiers, and bound values. Document any intentional system-mode boundary.
- No SOQL/DML in production loops. Test bulk behavior, errors, access denial, and continuation correctness. Never use SeeAllData=true.
- Before finishing code changes, run npm test, npm run analyze:core, and npm run validate:core -- --target-org <development alias>. Validate local source and tests together.
- Keep retrieved org changes and local changes recoverable before synchronization. Retrieve into an isolated project and review differences before overlaying source.
- Other modules and historical CRM source are preserved on feature/developer-kit-foundation. Keep unrelated modules on their own feature branches.
- Do not include auth files, credentials, generated analyzer reports, or .local-state recovery snapshots in commits.

- Develop each feature on a separate feature/<module>-<purpose> branch from main. Keep its implementation, metadata, tests, examples, and docs together. Merge completed, validated features through a pull request into main; do not develop features directly on main. See CONTRIBUTING.md.

# Engineering & Coding Standards

## Core Philosophy

- Write code for human readers first.
- Prefer simplicity, clarity, and maintainability.
- Follow existing project conventions.
- Avoid cleverness and overengineering.
- Every abstraction must justify its existence.

## 1. Visual Readability

- Use consistent indentation and spacing.
- Group statements by logical responsibility.
- Separate distinct logical phases with one blank line.
- Keep closely related statements together.
- Avoid excessive vertical whitespace.
- Prefer short, readable expressions.
- Format code so its logical flow is visually obvious.

## 2. Control Flow

- Prefer guard clauses over deep nesting.
- Use single-line if statements for short,
  simple, single-statement conditions.
- Omit braces only when safe and consistent
  with the project's formatter.
- Use braces for complex or multi-line branches.
- Avoid nested ternaries and clever one-liners.
- Prefer explicit control flow when it improves clarity.

## 3. Abstraction & Design

- Abstract meaningful behavior, not syntax.
- Do not extract methods solely to reduce line count.
- Avoid trivial one-line wrapper methods.
- Extract methods when they:
  - Encapsulate meaningful business rules.
  - Remove substantial duplication.
  - Isolate distinct responsibilities.
  - Make complex logic easier to understand.
- Avoid premature abstractions.
- Do not introduce interfaces or base classes
  without a concrete requirement.
- Prefer composition over unnecessary inheritance.
- Keep simple code simple.

## 4. Naming

- Use concise, intention-revealing names.
- Prefer business-domain terminology.
- Avoid vague names such as processData,
  handleStuff, or executeLogic.
- Avoid unnecessarily verbose names.
- Maintain naming consistency across layers.

## 5. Code Organization

- Keep related logic close together.
- Separate validation, business logic,
  transformation, and persistence when useful.
- Follow existing architectural boundaries.
- Avoid excessive indirection across files.
- Avoid unnecessary helper and utility classes.
- Prefer cohesive methods over fragmented code.

## 6. Comments

- Explain WHY, not WHAT.
- Avoid comments describing obvious statements.
- Document non-obvious business rules,
  constraints, and design decisions.
- Do not add decorative comments.

## 7. Change Discipline

- Make the smallest coherent change.
- Preserve behavior unless explicitly requested.
- Avoid unrelated refactoring.
- Do not introduce speculative requirements.
- Ensure correctness before optimizing style.

## 8. Final Self-Review

Before finishing, verify:

- Is the code visually clean?
- Are logical blocks grouped appropriately?
- Can unnecessary abstractions be removed?
- Are all abstractions meaningful?
- Is the control flow easy to follow?
- Are names concise and understandable?
- Does the code match project conventions?
- Are behavior and tests preserved?
