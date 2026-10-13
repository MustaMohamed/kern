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

A phrase also switches, without this skill:
- terse voice: "terse mode", "go terse", "be terse", "switch to terse", "terse on", "use terse", "enable terse", "turn on terse", "activate terse", "terse please";
- normal voice: "normal mode", "back to normal", "go back to normal", "switch back to normal", "switch to normal", "stop terse", "terse off", "terse mode off", "turn off terse", "disable terse", "exit terse", "quit terse", "normal voice";
- html surface: "html mode", "go html", "switch to html", "html on";
- surface back to the settings default, or `auto` when that default is `html`: "stop html", "html off";
- chat surface: "chat only", "chat mode";
- autopilot off: "stop autopilot", "autopilot off".

The phrase must open the prompt's first line, after an optional "please" or "ok". It switches only when it is the whole line, or when punctuation or the word "and", "then", "now" or "please" follows it. "go terse, then fix the test" switches. "go terse for the rest of this session" does not. A voice phrase that ends in "terse" or "normal" may add "mode", as in "turn off terse mode". "terse" switches only as the whole line. A first line that ends with "then go terse" or "then stop terse", as in "fix the test, then go terse", switches too. A first line that holds a question mark, or opens with a question word or a negation such as "don't go terse", never switches.
