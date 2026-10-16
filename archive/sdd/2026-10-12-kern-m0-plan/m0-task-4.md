### Task 4: Manifests, changelog and the placeholder skill

**Files:**
- Create: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`, `skills/hello/SKILL.md`

**Interfaces:**
- Consumes: nothing.
- Produces: plugin version `0.1.0` in both manifests and CHANGELOG; `skills/hello` is the one auto skill until M2 removes it (M2 deletes `skills/hello/` and `evals/cases/hello.json` in the same commit that adds the first real auto skill).

- [ ] **Step 1: Run the validator to see it fail**

Run: `claude plugin validate . --strict`
Expected: non-zero exit; the report says no manifest was found.

- [ ] **Step 2: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "kern",
  "version": "0.1.0",
  "description": "Personal workflow kernel for Claude Code: routing, guarded autonomy, proof before done, and project settings that defer to each repo's own rules.",
  "author": { "name": "Mustafa Mohamed" },
  "repository": "https://github.com/OWNER/kern",
  "license": "MIT",
  "skills": "./skills"
}
```

Replace `OWNER` with the output of `gh api user --jq .login` before writing the file.

- [ ] **Step 3: Write `.claude-plugin/marketplace.json`**

```json
{
  "$schema": "https://json.schemastore.org/claude-code-marketplace.json",
  "name": "kern",
  "description": "The kern plugin, served from its own repo.",
  "owner": { "name": "Mustafa Mohamed" },
  "plugins": [
    {
      "name": "kern",
      "version": "0.1.0",
      "source": "./",
      "description": "Personal workflow kernel for Claude Code: routing, guarded autonomy, proof before done, and project settings that defer to each repo's own rules.",
      "license": "MIT"
    }
  ]
}
```

- [ ] **Step 4: Write `CHANGELOG.md`**

```markdown
# Changelog

All notable changes to kern. Format: Keep a Changelog. Versioning: semver, as defined in docs/specs/2026-10-12-kern-design.md section 12.

## [Unreleased]

## [0.1.0] - 2026-10-12

- Repo, manifests, licences, lint, routing evals and CI with a placeholder skill.
```

Set the release date to the day the task runs.

- [ ] **Step 5: Write `skills/hello/SKILL.md`**

```markdown
---
name: hello
description: Use when the user says hello to kern or asks whether kern is installed. Replies with the kern version from plugin.json. Placeholder until M2 adds real auto skills.
---

# hello

## Steps

1. Read `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
2. Reply in one line: `kern <version> is installed.`
```

- [ ] **Step 6: Run the validator to verify it passes**

Run: `claude plugin validate . --strict; echo "exit=$?"`
Expected: `exit=0`. If a warning fails `--strict`, fix the field it names; do not drop `--strict`.

- [ ] **Step 7: Commit**

```bash
git add -- .claude-plugin CHANGELOG.md skills/hello/SKILL.md
git commit -m "M0: add plugin and marketplace manifests with a placeholder skill" -m "The repo is its own marketplace (source ./), so one install command works on any machine."
```

---

