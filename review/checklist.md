# Review Checklist

Referenced by `SKILL.md`. Two-pass structure: CRITICAL issues first, then INFORMATIONAL.

---

## Pass 1 -- CRITICAL

These issues will cause bugs, security vulnerabilities, data loss, or production incidents.

### SQL & Data Safety (all stacks)

- [ ] **SQL injection via string interpolation**
  - Python: f-strings or `%` formatting in SQL queries instead of parameterized queries
  - JavaScript/TypeScript: template literals in SQL queries instead of parameterized queries
  - Odoo: raw SQL with `%s` not passed as tuple, or string concatenation in `cr.execute()`
- [ ] **N+1 query patterns**
  - Loop containing individual DB queries that should be batched
  - Flask: `db.session.query()` or `.get()` inside a for-loop
  - Odoo: `browse()` or `search()` inside a for-loop
- [ ] **TOCTOU race conditions**
  - Check-then-act patterns without locking (e.g., check if record exists, then create)
  - File existence check followed by file operation without atomic guarantees
- [ ] **Unvalidated user input in database operations**
  - User-supplied values used in `ORDER BY`, column names, or table names
  - Dynamic query construction from request parameters

### Python/Flask Specific

- [ ] **SQLite concurrent writes without WAL mode**
  - Multiple writers to SQLite without `PRAGMA journal_mode=WAL`
- [ ] **`os.environ.get()` without fallback for required vars**
  - Required config vars using `.get()` with no default — will silently return `None`
  - Should use `os.environ["VAR"]` for required vars (raises `KeyError`) or `.get()` with explicit default
- [ ] **Routes missing `@login_required`**
  - New route handlers that access user data or perform mutations without auth decorator
  - Compare against existing routes in the same file for the expected pattern
- [ ] **Bare `except:` or `except Exception:`**
  - Catches everything including `SystemExit`, `KeyboardInterrupt`
  - Must catch specific exception types
- [ ] **`eval()` or `exec()` with user input**
  - Any use of `eval()` or `exec()` where the argument traces back to request data
- [ ] **Hardcoded secrets**
  - API keys, tokens, passwords, or secret keys as string literals instead of env vars
  - Look for patterns: `key = "sk-..."`, `token = "..."`, `password = "..."`

### TypeScript/React Specific

- [ ] **`any` types in function signatures or return types**
  - Function parameters typed as `any`
  - Return types explicitly or implicitly `any`
  - Type assertions to `any` (`as any`)
- [ ] **React hooks called conditionally or in loops**
  - `useState`, `useEffect`, `useMemo`, `useCallback` inside `if`, `for`, `while`, or after early returns
- [ ] **Missing error boundaries around async components**
  - Components that `await` data without a parent `ErrorBoundary`
  - Suspense boundaries without corresponding error boundaries
- [ ] **Environment variables exposed to client bundle**
  - Vite: env vars without `VITE_` prefix accessed in client code
  - Next.js: env vars without `NEXT_PUBLIC_` prefix accessed in client components
  - Any server-only secrets importable from client-side code
- [ ] **`dangerouslySetInnerHTML` with unsanitized input**
  - HTML set from user input, API responses, or database values without DOMPurify or equivalent

### Odoo Specific

- [ ] **New models missing access rules**
  - New `_name` declaration without corresponding `ir.model.access.csv` entry
  - No `ir.rule` record rules for multi-company or multi-user isolation
- [ ] **`sudo()` without justification**
  - Calls to `.sudo()` without a comment explaining why elevated privileges are needed
  - Especially dangerous in controllers or public-facing methods
- [ ] **XML view `id` collisions**
  - Duplicate `id` attributes across XML data files
  - IDs that could collide with base Odoo modules (not prefixed with custom module name)
- [ ] **`_inherit` without `_name`**
  - Using `_inherit = 'model.name'` without setting `_name` creates extension
  - Using both `_inherit` and `_name` (different) creates delegation inheritance
  - Verify the developer intended the correct pattern
- [ ] **Missing `groups` on menus and actions**
  - `ir.ui.menu` or `ir.actions.act_window` without `groups` attribute
  - Exposes functionality to all users by default
- [ ] **Direct SQL bypassing ORM security**
  - `self.env.cr.execute()` for operations that should use ORM methods
  - Bypasses access rules, record rules, and field-level security

### Trust Boundaries (all stacks)

- [ ] **LLM/AI output written to DB without validation**
  - AI-generated content stored directly without schema validation or sanitization
  - Prompt injection vectors that could alter stored data
- [ ] **User input rendered without sanitization (XSS)**
  - User-supplied strings rendered as HTML without escaping
  - Odoo: `t-raw` with user-controlled data (use `t-esc` instead)
  - React: rendering user input outside JSX auto-escaping
- [ ] **API responses trusted without schema validation**
  - External API responses used directly without type checking or validation
  - Missing error handling for unexpected response shapes

---

## Pass 2 -- INFORMATIONAL

These are code quality, maintainability, and best-practice issues. They should be improved
but will not break production.

### CLAUDE.md Compliance

- [ ] **Suppression comments**
  - `@ts-ignore`, `@ts-expect-error` in TypeScript
  - `eslint-disable` (inline or file-level) in JavaScript/TypeScript
  - `# noqa` in Python
  - `noinspection` in any language
  - `istanbul ignore` for coverage
- [ ] **Empty or log-only catch blocks**
  - `catch (e) {}` or `catch (e) { console.log(e) }` in JS/TS
  - `except: pass` or `except Exception as e: logger.error(e)` without re-raise in Python
  - `.catch(() => {})` swallowed promise rejections
- [ ] **Unused imports**
  - Imported symbols not referenced elsewhere in the file
  - Modules imported for side effects should have a comment explaining why
- [ ] **Files exceeding 500 lines**
  - Count total lines after applying the diff
  - Suggest extraction points if file is approaching or exceeding the limit
- [ ] **Naming convention violations**
  - Files/directories not in `kebab-case`
  - Variables/functions not in `camelCase`
  - React components not in `PascalCase`
  - Constants not in `UPPER_SNAKE_CASE`
  - Exception: follow existing repo conventions if they differ

### Code Quality

- [ ] **DRY violations**
  - Same logic duplicated in multiple places within the diff
  - Reference both locations with file and line number
  - Suggest extraction into a shared function or module
- [ ] **Magic numbers or hardcoded strings**
  - Numeric literals without explanation (except 0, 1, -1)
  - String literals that represent config values, URLs, or messages
  - Should be extracted to named constants
- [ ] **Dead code or stale comments**
  - Commented-out code blocks
  - TODO comments for work already done in this diff
  - Unreachable code after return/throw/raise
- [ ] **Circular dependencies**
  - Module A imports from B, and B imports from A (directly or transitively)
  - Check import graph for new files added in the diff
- [ ] **Missing JSDoc/docstring on exported functions**
  - Public functions without documentation
  - Complex parameters without `@param` descriptions
  - Non-obvious return values without `@returns`

### Test Gaps

- [ ] **New functions/routes without tests**
  - New endpoint handlers without corresponding test file or test cases
  - New utility functions without unit tests
  - Only flag if the repo already has a test suite
- [ ] **Missing negative-path tests**
  - Tests only cover successful cases
  - No tests for invalid input, auth failures, or error conditions
- [ ] **Happy-path-only tests**
  - Tests that only verify the expected output without edge cases
  - Missing boundary condition tests (empty input, max values, null)

### Performance

- [ ] **N+1 queries**
  - Flask: individual DB queries inside a loop (should use `in_()` or join)
  - Odoo: `browse()` in loop (should batch IDs), `search()` in loop
  - React: multiple sequential API calls that could be parallelized
- [ ] **Missing database indexes**
  - New query patterns filtering on columns without indexes
  - Odoo: new `search()` calls on fields without `index=True`
- [ ] **Expensive operations without caching**
  - Repeated identical computations or API calls
  - Data that could be memoized or cached
- [ ] **Large payloads without pagination**
  - API endpoints returning unbounded result sets
  - Missing `limit`/`offset` or cursor-based pagination

### Deployment Risk

- [ ] **New env vars not in `.env.example`**
  - Code references `process.env.NEW_VAR` or `os.environ["NEW_VAR"]`
  - But `.env.example` not updated in the diff
- [ ] **Hardcoded URLs**
  - `localhost`, `127.0.0.1`, or staging URLs in production code paths
  - URLs that should come from environment configuration
- [ ] **Missing feature flags**
  - Large behavioral changes without a feature flag or toggle
  - Risky changes that cannot be easily rolled back
- [ ] **Risky database migrations**
  - Migrations that lock tables (adding NOT NULL column without default)
  - Migrations that rewrite large tables (changing column type)
  - Missing reverse migration

---

## DO NOT Flag

Suppress findings that match any of these criteria:

- **Style preferences** that do not affect correctness (e.g., single vs double quotes,
  trailing commas, brace style) unless they violate explicit CLAUDE.md rules
- **Framework boilerplate** — Odoo manifest fields, React import patterns,
  Flask app factory structure, standard `__init__.py` re-exports
- **Existing code not modified in this diff** — only review changed or added lines
- **Minor formatting differences** in files the developer did not modify
- **Import ordering** unless it creates a circular dependency
- **Type narrowing choices** that are valid but not the reviewer's preference
