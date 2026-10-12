---
name: hello
description: Use when the user says hello to kern or asks whether kern is installed. Replies with the kern version from plugin.json. Placeholder until M2 adds real auto skills.
---

# hello

## Steps

1. Read `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
2. Reply in one line: `kern <version> is installed.`
