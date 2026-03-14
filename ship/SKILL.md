---
name: ship
version: 1.0.0
description: Automated release workflow for Pulse Integrated — multi-stack test detection, pre-landing review, version bumping, changelog generation, and PR creation. Non-interactive by default.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# /ship — Automated Release Workflow

## Philosophy

Non-interactive. User says `/ship`, next thing they see is a PR URL.

Only stop for:
- **On main** — abort immediately
- **Merge conflicts** — complex conflicts that cannot be auto-resolved
- **Test failures** — show failures and stop
- **CRITICAL review findings** — ask Fix/Acknowledge/Skip
- **MINOR/MAJOR version bumps** — ask user to confirm

Everything else is decided automatically. No "does this look good?" prompts. No summaries
before action. Ship it.

---

## Step 1: Pre-flight

Run these checks before anything else. If any fail, stop immediately.

### 1A: Branch Check

```
git rev-parse --abbrev-ref HEAD
```

If the result is `main` or `master`:

> **ABORT.** You are on the main branch. Create a feature branch first:
> `git checkout -b feature/<name>`

Do NOT proceed. Do NOT offer to create a branch. Stop.

### 1B: Working Tree Status

```
git status
```

Never use `-uall`. Report untracked files, staged changes, unstaged changes.

If there are uncommitted changes, commit them first with a descriptive message before
proceeding. Do not ask — just commit.

### 1C: Branch Diff Summary

Run in parallel:
```
git diff main...HEAD --stat
git log main..HEAD --oneline
```

If both return empty (no commits ahead of main):

> **ABORT.** No changes to ship. This branch is even with main.

Store the diff stat and commit log for use in PR body generation.

---

## Step 2: Merge origin/main

```
git fetch origin main
git merge origin/main --no-edit
```

### Auto-resolve simple conflicts:
- **VERSION file** — keep the branch version (it will be bumped in Step 5)
- **CHANGELOG.md ordering** — keep both entries, re-sort by date descending

### Stop for complex conflicts:
If merge conflicts remain after auto-resolution:

> **Merge conflicts require manual resolution.**
> Conflicting files: [list]
> Resolve conflicts, then run `/ship` again.

Do NOT attempt to resolve code conflicts automatically.

---

## Step 3: Run Tests (Auto-Detect Stack)

Detect the project stack by scanning files in the repo root and subdirectories.

### Detection Rules

| Signal | Stack | Test Command |
|--------|-------|-------------|
| `requirements.txt` with `pytest` or `conftest.py` exists | Python/Flask | `pytest` or `python -m pytest` |
| `package.json` with `test` script | TypeScript/React | `npm test` or `bun test` (check for bun.lockb) |
| `__manifest__.py` in any subdirectory | Odoo | Print note and skip |

### Execution

- If **Python/Flask** detected: run `pytest -v --tb=short`
- If **TypeScript/React** detected: run `npm test` (or `bun test` if bun.lockb exists)
- If **Odoo** detected: print "Odoo module tests should be verified on staging. Continuing."
- If **multiple stacks** detected: run all applicable test commands sequentially
- If **no test framework** detected: print "No test framework found. Skipping tests."

### On Failure

If any test command exits non-zero:

> **Tests failed. Shipping stopped.**
> [Show test output — last 50 lines]
>
> Fix the failures and run `/ship` again.

Do NOT proceed past failed tests. Do NOT offer to skip them.

---

## Step 4: Pre-Landing Review

### 4A: Load Checklist

Read the review checklist from these paths in order (first readable wins):
1. `~/.claude/skills/pulse-claude-skills/review/checklist.md`
2. `.claude/skills/pulse-claude-skills/review/checklist.md`

If neither is readable:

> **STOP.** Cannot find review checklist. Expected at:
> `~/.claude/skills/pulse-claude-skills/review/checklist.md`
> Ensure the review skill is installed.

### 4B: Two-Pass Review

Run against the full diff from main:
```
git diff origin/main
```

**Pass 1 — Mechanical:** Check every item in the checklist. Binary pass/fail per item.

**Pass 2 — Judgment:** Read the diff as a reviewer. Look for:
- Logic errors, off-by-one, race conditions
- Missing error handling on new code paths
- Security concerns (credentials, injection, auth bypass)
- Performance regressions (N+1 queries, unbounded loops, missing indexes)

### 4C: Output Findings

Categorize each finding:
- **CRITICAL** — Must fix before shipping (security, data loss, crash)
- **WARNING** — Should fix, but shippable (style, minor performance)
- **NOTE** — Informational (suggestions, future improvements)

### 4D: Handle Critical Findings

For each CRITICAL finding, use AskUserQuestion:

> **CRITICAL: [description]**
> File: [path]:[line]
>
> (A) Fix it now — I will apply the fix and re-run tests
> (B) Acknowledge — Ship with known issue
> (C) Skip — I disagree this is critical

If the user chooses (A): apply the fix, commit it, and re-run Step 3 (tests).
If the user chooses (B): note in PR body under "Known Issues."
If the user chooses (C): downgrade to WARNING in PR body.

---

## Step 5: Version Bump (If Applicable)

Check for version files:

| File | Format | Bump Strategy |
|------|--------|--------------|
| `VERSION` | 4-digit (`MAJOR.MINOR.MICRO.BUILD`) | Auto-increment BUILD for small changes |
| `package.json` | 3-digit semver (`MAJOR.MINOR.PATCH`) | Auto-increment PATCH for small changes |

### Auto-pick MICRO/PATCH
If the branch diff is fewer than 100 lines changed and touches fewer than 5 files,
auto-increment the smallest version component. No prompt.

### Ask for MINOR/MAJOR
If the diff is larger, or if the branch name contains `feature/` or the commits mention
"breaking change," use AskUserQuestion:

> Version is currently **X.Y.Z**. This looks like a [feature/breaking change].
>
> (A) PATCH — bug fix, no new features → X.Y.(Z+1)
> (B) MINOR — new feature, backward compatible → X.(Y+1).0
> (C) MAJOR — breaking change → (X+1).0.0

If no version file exists, skip this step entirely.

---

## Step 6: CHANGELOG (Auto-Generate)

### 6A: Read Existing Format

Read `CHANGELOG.md` if it exists. Match its formatting conventions (header style, category
names, date format). If no CHANGELOG exists, create one with this format:

```markdown
# Changelog

## [version] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...

### Removed
- ...
```

### 6B: Generate Entry

Read all commits on the branch:
```
git log main..HEAD --format="%s"
```

Categorize each commit message into Added/Changed/Fixed/Removed. Write concise, user-facing
descriptions (not raw commit messages). Prepend the new entry to the changelog.

---

## Step 7: Commit (Bisectable Chunks)

Split uncommitted changes into logical, independently valid commits. Order:

1. **Infrastructure** — config files, dependencies, build changes
2. **Models/Services** — data layer, business logic
3. **Controllers/Views** — routes, templates, UI components
4. **Version/Changelog** — version bump and changelog entry

Each commit must leave the project in a buildable state. Only the **final commit** gets the
Co-Authored-By trailer:

```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

If all changes are small enough to be a single logical commit, use one commit.

---

## Step 8: Push

```
git push -u origin <current-branch-name>
```

If push fails due to remote changes, pull with rebase and retry once:
```
git pull --rebase origin <current-branch-name>
git push -u origin <current-branch-name>
```

If it fails again, stop and report the error.

---

## Step 9: Create PR

Use `gh pr create` with a structured body.

### PR Body Template

```markdown
## Summary
[Generated from CHANGELOG entry — 2-5 bullet points]

## Pre-Landing Review
- **CRITICAL:** [count] ([count] fixed, [count] acknowledged)
- **WARNING:** [count]
- **NOTE:** [count]

[List any acknowledged critical issues under "Known Issues"]

## Test Results
- [Stack]: [PASS/FAIL] ([test count] tests)
- Odoo: Verify on staging

## Deploy Target
[Auto-detected per stack — see rules below]

## Test Plan
- [ ] [Generated checklist items based on what changed]
```

### Deploy Target Detection

| Stack | Deploy Target |
|-------|--------------|
| Python/Flask (Render) | "Deploys to Render on merge to main" |
| TypeScript/React (DCC) | "Deploys to Cloud Run via Cloud Build" |
| Odoo | "Deploy via Odoo.sh staging branch" |

Detect from project files. If unclear, omit the deploy target section.

### Final Output

Print the PR URL. That is the last thing the user sees.

```
PR created: https://github.com/org/repo/pull/123
```

---

## Rules (Non-Negotiable)

1. **Never skip tests.** If tests exist, they run. Period.
2. **Never skip review.** The checklist review always runs.
3. **Never force push.** Use `git push`, never `git push --force`.
4. **Never ask for confirmation** except for MINOR/MAJOR version bumps and CRITICAL findings.
5. **Never modify files outside the repo** (no global config changes).
6. **Always use `--no-edit`** for merge commits to avoid interactive editors.
7. **If anything unexpected happens,** stop and report. Do not improvise recovery steps.
