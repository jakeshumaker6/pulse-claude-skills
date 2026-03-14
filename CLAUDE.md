# pulse-claude-skills

Custom Claude Code skills for Pulse Integrated.

## Repo Rules

This repo contains only Markdown skill files. No compiled code, no dependencies.

### Skill File Conventions

- Each skill is a directory at the repo root containing a `SKILL.md`
- Supporting files (checklists, reference docs) live in the same directory
- **Max 500 lines per file**
- **File naming:** `kebab-case` directories, `SKILL.md` for the main skill file, `kebab-case.md` for supporting files
- YAML frontmatter is required: `name`, `version`, `description`, `allowed-tools`
- `allowed-tools` must list every tool the skill uses (including specific MCP tool names)

### Skill Authoring Guidelines

- Skills must not modify files unless the user explicitly requests it
- Skills using MCP integrations must handle unavailable tools gracefully (report to user, continue with available data)
- Each skill needs a clear output format section showing expected output structure
- Use AskUserQuestion for any decision with meaningful tradeoffs
- No external binary dependencies except gstack's browse binary (used by `/qa` only)

### Adding a New Skill

1. Create a new directory: `my-skill/`
2. Create `my-skill/SKILL.md` with YAML frontmatter
3. Run `./setup` to create the symlink
4. Test by typing `/my-skill` in Claude Code

### Testing a Skill

Run the skill in Claude Code and verify:

- Frontmatter parses correctly (skill appears in `/` autocomplete)
- All referenced MCP tools are available
- Output format matches the spec
- Error cases are handled (no MCP access, no data found, wrong client name)

### Commands

No build, test, or lint commands. This is a Markdown-only repo. Verification is manual: run each skill in Claude Code and confirm it works.
