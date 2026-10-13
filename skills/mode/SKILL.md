---
name: mode
description: Switch voice (normal, terse) and surface (chat, auto, html) for this session, or show the current mode.
disable-model-invocation: true
argument-hint: "[terse|normal|chat|auto|html|default|status]"
allowed-tools: Read
---

# Mode

kern's prompt hook applies the switch before this skill loads. This skill only reports what the hook did.

## Steps
1. Read the `kern mode:` line the hook injected this turn.
2. No such line: reply "the mode hook did not run; nothing changed" and name the likely cause: bash missing, hooks disabled, or `kern: off` in the project settings. Never write or edit the session state file; guard G16 denies it.
3. `status`, or no argument: report voice, surface and autopilot. For each, give the default and where it comes from, using the Project settings block of the kernel (`mode.voice`, `mode.surface`, `autopilot`).
4. Surface `html` or `auto` while kern has no `visual` skill installed: add one line that visual pages arrive with the visual skill and replies stay in chat until then.
5. Reply in one line. The terse voice governs chat only. Files, commits, PR bodies and pages stay in plain prose.

## Words
`terse` and `normal` set the voice. `chat`, `auto` and `html` set the surface. `default` resets both to the settings defaults. `status` changes nothing. Words combine, as in `/kern:mode html terse`. An unknown word changes nothing.

A phrase that opens the prompt also switches, without this skill: "go terse", "terse mode", "back to normal", "html mode", "stop html", "chat only". A question or a negation, such as "don't go terse", never switches.
