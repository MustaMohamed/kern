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

A phrase below also switches, without this skill, only when it stands alone on the prompt's first line: put the phrase alone on the first line, or type `/kern:mode`. A leading "please" or "ok", a trailing "please" or "now", a final "." or "!", and "mode" after "terse" or "normal" are allowed; with anything else on the line, as in "go terse and fix the bug", nothing switches.
- terse voice: "terse", "go terse", "be terse", "use terse", "enable terse", "turn on terse", "activate terse", "switch to terse", "terse on", "terse mode";
- normal voice: "normal", "normal mode", "normal voice", "back to normal", "go back to normal", "switch back to normal", "switch to normal", "stop terse", "terse off", "terse mode off", "turn off terse", "disable terse", "exit terse", "quit terse";
- html surface: "html mode", "go html", "switch to html", "html on";
- surface back to the settings default, or `auto` when that default is `html`: "stop html", "html off";
- chat surface: "chat only", "chat mode";
- autopilot off: "stop autopilot", "autopilot off".
