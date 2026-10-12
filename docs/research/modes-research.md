# Session modes research: caveman, html, auto

Read-only research. Nothing was run. Paths are abbreviated:

- `CV` = `~/.claude/plugins/cache/caveman/caveman/3.2.0`
- `SP` = `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills/brainstorming`
- `PK` = `<scratchpad>/repos/pocock/skills/skills/engineering`
- `PS` = `<scratchpad>/repos/cursor/plugins/pstack`
- `AD` = `<scratchpad>/repos/addy/agent-skills`

Token figures use 4 bytes per token.

## 1. Caveman plugin mechanics

### Hooks (all declared inline in `CV/.claude-plugin/plugin.json`; `CV/hooks/` holds only `hooks-cursor.json`)

| Event | Script | Job |
|---|---|---|
| SessionStart (no matcher) | `src/hooks/caveman-activate.js` | Resolve the mode, persist it, inject the full skill body |
| SubagentStart | `caveman-activate.js --subagent` | Inject the parent session's skill into each subagent. Read-only (`caveman-activate.js:286-300`) |
| UserPromptSubmit | `src/hooks/caveman-mode-tracker.js` | Parse switches, write state, emit per-turn reminder |
| SessionEnd | `src/hooks/caveman-stats.js --record` | Append token snapshot to `~/.claude/.caveman-history.jsonl`. No network calls in any hook (`grep -n "https\?://\|fetch(" src/hooks/*.js` returns nothing) |

Every command is guarded by `command -v node || exit 0`, and each spawns a fresh node process per event.

### Mode state

| Item | Location | Ref |
|---|---|---|
| Per-session mode | `$CLAUDE_CONFIG_DIR/.caveman-sessions/<session_id>.mode` (+ `.prev` for one-shot restore) | `caveman-config.js:79`, `:495` |
| Legacy mirror, last write wins | `~/.claude/.caveman-active`. Never contains `off`; deactivation deletes it | `src/hooks/README.md` "Where the mode lives" |
| Transition log | `~/.claude/.caveman-mode-log.jsonl` | `caveman-config.js:676-691` |
| GC | Session files older than 14 days, swept on `startup`/`clear` only | `caveman-activate.js:389-394` |
| Default resolution | `CAVEMAN_DEFAULT_MODE` env, then repo `.caveman.json` or `.caveman/config.json` (walks up), then `~/.config/caveman/config.json`, then `caveman` | `caveman-config.js:148-166` |
| Headless | `claude -p` / SDK entrypoints start in `manual` (nothing injected) | `caveman-activate.js:247-256` |
| Scheduled tasks | Tracker bails entirely on `<scheduled-task` | `caveman-mode-tracker.js:156-163` |

Writes are symlink-safe, atomic, mode 0600 (`caveman-config.js:171-260`). Reads cap size and whitelist values before anything reaches model context (`caveman-mode-tracker.js:335-339`).

### Compaction and resume

SessionStart fires on `startup`, `resume`, `clear`, `compact`, `fork`. Only `startup` and `clear` re-derive the default. The others read the stored literal value, so an explicit `off` survives `/compact` (`caveman-activate.js:207-245`, `:387-411`). A 2 s stdin watchdog that times out uses source `unknown`, which never resets (`:227-234`).

### Switching

- Slash commands arrive at UserPromptSubmit as a `<command-name>/caveman</command-name><command-args>ultra</command-args>` envelope. The tracker rebuilds `"/caveman ultra"` from it. A foreign command's envelope disables NL parsing for that turn (`caveman-mode-tracker.js:165-189`).
- `/caveman status`: injects `Report this status verbatim without changing mode: Caveman mode: <mode>` and changes nothing (`:243-255`).
- Off: NL `stop|disable|deactivate|quit|exit|kill caveman`, `caveman off`, `turn off caveman`, prompt-initial `normal mode` (`caveman-parse.js:250-260`). Off writes a durable `off` and clears `.prev` (`caveman-mode-tracker.js:319-326`).
- On: NL verb phrases (`activate|enable|start|turn on|use|switch to|want|give me ... caveman`), `talk like caveman`, `caveman mode on`, and brevity triggers (`less tokens`, `be brief`, `be terse`, `shorter answers`, unless scoped like "be brief in the summary"). A clause-scoped negation guard blocks "don't use caveman"; questions ("what is caveman mode?") never activate (`caveman-parse.js:100-170`, `:286-290`).
- Bad argument: a notice "argument not recognized, mode unchanged". The rejected text is never echoed into context (`caveman-mode-tracker.js:257-277`).

### Sub-modes

`caveman`, `ultracave`, `megacave` are separate skills, each with its own `SKILL.md` and its own `/ultracave`, `/megacave` command (`disable-model-invocation: true` in their frontmatter). `ultra`, `wenyan*`, `lite`, `full` are legacy aliases mapped to them (`caveman-activate.js:79-85`). `commit`, `review`, `compress` are one-shot "independent" modes. The tracker saves the displaced prose mode in `.prev` and restores it on the next ordinary prompt (`caveman-mode-tracker.js:287-360`). A genuine switch re-injects the new mode's whole ruleset on that turn, not just a relabelled banner (`:372-389`, issue #975).

### Statusline

`src/hooks/caveman-statusline.sh` reads `session_id` from the statusline stdin JSON with a 1 s `read -t` ceiling, whitelists the id, refuses symlinks, caps the read at 64 bytes, strips to `[a-z0-9-]`, maps to `[CAVEMAN]`, `[ULTRACAVE]`, `[MEGACAVE]`, `[CAVEMAN:COMMIT]`, and renders nothing for `off` (`:26-76`). SessionStart nudges once if no `statusLine` is configured, gated by `~/.claude/.caveman-nudge-shown` (about 90 tokens, `caveman-activate.js:443-604`). It copies the script to a version-independent `~/.claude/hooks/` path so plugin cache pruning cannot break the status bar (`:447-484`). This machine has no `statusLine` in `~/.claude/settings.json`.

### Injected text size

| When | What | Bytes | Tokens |
|---|---|---|---|
| Each SessionStart (startup, clear, compact, resume) | Banner + `skills/caveman/SKILL.md` body without frontmatter + switch line | about 4,550 (body 4,431, 707 words) | about 1,140 |
| Same, ultracave / megacave | Body 2,249 / 2,590 | | about 580 / 670 |
| Each user prompt while active | `reinforcementForMode()` (`caveman-mode-tracker.js:114-120`) | 409 (57 words) | about 100 |
| Each subagent spawn | Same ruleset as SessionStart | about 4,550 | about 1,140 |
| Mode switch turn | New mode's full ruleset + reminder | about 4,950 | about 1,240 |
| First session only | Statusline nudge | | about 90 |

A 50-prompt session with 10 subagents and 2 compactions pays about 1,140 × 3 + 100 × 50 + 1,140 × 10 = about 19.8k input tokens of instructions, before prompt caching.

## 2. Caveman licensing verdict

Files: `CV/LICENSE` (verbatim Apache-2.0), `CV/LICENSE-MIT` (pre-3.0.0 MIT text), `CV/LICENSING.md`, `CV/NOTICE`, `CV/TRADEMARKS.md`.

- **Code and rule text.** Since 3.0.0 everything in the repo, skills and `SKILL.md` text included, is Apache-2.0 (`LICENSING.md` "Everything in this repository..."). You may copy, modify and redistribute the rules text and the hook code. Conditions (Apache §4): ship a copy of the License, mark modified files as changed, keep the copyright notices (`Copyright 2026 Julius Brussee`), and carry the attribution notices from `NOTICE` that pertain to what you copied. Pre-3.0 contributor code in the formerly MIT parts also stays under MIT, whose notice must travel with it (`LICENSING.md` "What changed in 3.0.0"). Copying ideas only (answer first, kill ceremony, ASD-STE100 sentence limit) carries no obligation. Expression is copyrighted, technique is not.
- **The name.** "Caveman", its wordmark and rock logo are trademarks with pending applications (`TRADEMARKS.md`). Apache grants no trademark rights. Allowed without permission: "works with Caveman", "compatible with Caveman", referring to the project in docs. Needs written permission: naming your own product, mode, fork or service "Caveman" or anything confusingly similar ("ultracave" and "megacave" are their marks too), using the logo, or implying endorsement.
- **Practical reading for a personal plugin.** A mode literally named `caveman` that is your own implementation is the case `TRADEMARKS.md` restricts once the plugin is published or shared. A mode that forwards to the installed caveman plugin may truthfully be labelled "caveman (via the Caveman plugin)".

### Recommendation: embed your own terse mode, do not depend on the plugin

| | Depend on caveman plugin | Embed own `terse` mode |
|---|---|---|
| State machines | Two. Caveman's hooks keep injecting rules after you switch to `html` unless your plugin writes caveman's private `.caveman-sessions/*.mode` format, which can change on any release | One. Mode is a single field your hooks own |
| Install weight | Go engine, proxy, MCP server, cloud skills, 4 hooks spawning node per event, statusline nudge, SessionEnd stats | One hook script and one rules file |
| Per-session cost | about 1,140 tokens at start + 100 per prompt + 1,140 per subagent | Ruleset can be 400 to 600 tokens; reminder about 40 tokens |
| Portability | Needs node; Codex/Gemini paths exist but are caveman's, not yours | Yours to port |
| License | None to comply with | Apache §4 if you copy text; none if you write fresh |

Name it `terse`. Write the ruleset fresh (or copy with LICENSE + NOTICE + "modified" markers). Optionally detect `~/.claude/plugins/cache/caveman` and warn once that two style injectors are active. Take caveman's engineering lessons, which are not copyrightable: per-session state keyed by `session_id`, no reset on `compact`/`resume`, durable `off`, full ruleset on switch, headless and scheduled-task opt-out, SubagentStart injection, symlink-safe writes.

## 3. Superpowers visual companion

### Architecture

| Piece | Mechanism | Ref |
|---|---|---|
| Launch | `start-server.sh` makes `<project>/.superpowers/brainstorm/<pid>-<ts>/{content,state}` (or `/tmp/brainstorm-<id>`), `nohup node server.cjs &`, waits up to 5 s for `server-started`, prints JSON with `url`, `screen_dir`, `state_dir` | `scripts/start-server.sh:113-209` |
| Server | Zero-dependency node HTTP + hand-written RFC 6455 WebSocket, 723 lines | `scripts/server.cjs:1-81`, `:587-588` |
| Writing pages | Claude uses its file Write tool to create a new `.html` per screen in `screen_dir`. Never reuse names. Server serves the newest by mtime | `visual-companion.md:108-113`, `server.cjs:267-278` |
| Fragment vs document | A file not starting with `<!doctype`/`<html` is wrapped in `frame-template.html` (CSS theme, header, status pill). Full documents are served as-is. `helper.js` is injected into both | `server.cjs:258-265`, `:406-419` |
| Browser update | `fs.watch` on `content/`, 100 ms debounce, broadcasts `{type:"reload"}` over WebSocket; page does `location.reload()` | `server.cjs:590-613`, `helper.js:97-101` |
| Clicks back to Claude | `helper.js` captures clicks on `[data-choice]` and sends `{type:"click",choice,text,id}` over WebSocket. Server appends events that carry `choice` to `state/events` (JSONL) | `helper.js:129-141`, `server.cjs:503-517` |
| Claude reads clicks | Pull only. On its next turn, after the user types in the terminal, Claude reads `state/events`. The browser cannot wake Claude | `visual-companion.md:120-124` |
| Events lifetime | `state/events` is deleted whenever a new screen file appears | `server.cjs:601-605` |
| Lifecycle | Owner-PID watchdog (harness PID = grandparent of the script), 4 h idle timeout, `server-stopped` marker, tombstone overlay after 15 s disconnected, exponential reconnect, same-port restart via `.last-port`/`.last-token` | `server.cjs:552-657`, `helper.js:2-4`, `:103-114`, `start-server.sh:118-121`, `:153-159` |
| Stop | `stop-server.sh` verifies a per-start instance id in the process argv before killing; deletes the session dir only under `/tmp` | `stop-server.sh:63-115` |

### Security

- Binds `127.0.0.1` by default (`server.cjs:100`). `--host 0.0.0.0` is documented for remote/containers (`visual-companion.md:95-104`).
- Per-session 256-bit key (`crypto.randomBytes(32)`) required as `?key=` or cookie on every HTTP and WebSocket request, compared in constant time (`server.cjs:115-151`, `:321-353`). Bootstrap page moves the key into `sessionStorage` and drops it from the URL (`:188-200`, `:403-405`). Cookie is `HttpOnly; SameSite=Strict`, named per port (`:398-399`).
- WebSocket Origin must equal `http://<Host>` (`:377-383`). Frame payloads capped at 10 MiB (`:10`, `:58-67`). `/files/*` rejects dotfiles, symlinks, hard links, and paths outside `content/` (`:304-317`, `:420-433`).
- Headers: `no-referrer`, `no-store`, `X-Frame-Options: DENY`, CSP `frame-ancestors 'none'` only (`:366-375`). There is no `script-src`/`connect-src` restriction, so page content may load any remote resource. `visual-companion.md:278` recommends real Unsplash images.
- Startup JSON, token file and log are 0600 (`start-server.sh:109-111`, `server.cjs:676-688`).
- Browser auto-open is opt-in (`--open` sets `BRAINSTORM_OPEN`), loopback only, `execFile` with argv (no shell) unless `BRAINSTORM_OPEN_CMD` is set (`server.cjs:526-548`).

### Telemetry

- Every framed page and the waiting page render `<img src="https://primeradiant.com/brand/superpowers-visual-brainstorming-logo.png?v=<superpowers version>" referrerpolicy="no-referrer">` (`server.cjs:106`, `:242-256`, placed at `frame-template.html:202`). The browser fetches it on every reload, which tells Prime Radiant the version and the user's IP. Full-document screens skip the frame, so they skip the logo.
- Opt-out: any truthy value of `SUPERPOWERS_DISABLE_TELEMETRY`, `DISABLE_TELEMETRY`, or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` in the server process environment (`server.cjs:107-112`, `:227-232`). The server inherits the environment of the shell that ran `start-server.sh`. Disabled mode shows plain text "Prime Radiant Superpowers v<ver>".
- Documented in `superpowers/6.4.1/README.md:397-399`. License MIT, `Copyright (c) 2025 Jesse Vincent`.

### Token cost

- On acceptance Claude reads `visual-companion.md`, 13,413 bytes, about 3.4k tokens.
- Each screen costs the fragment's output tokens only (typically 0.5k to 3k). The 8,094-byte frame template and `helper.js` never enter context.
- Reading `state/events` is small. The skill itself warns the user it "can be token-intensive" (`SKILL.md:273`).

### Defects worth fixing if vendored

1. `window.brainstorm.choice(value)` sends `{type:"choice", value}` (`helper.js:163`), but the server persists only events with a `choice` key (`server.cjs:513`). Explicit API choices land in `server.log` only and never reach `state/events`.
2. Pushing a new screen deletes `state/events` (`server.cjs:603-604`). Clicks on screen N are lost if Claude pushes screen N+1 before reading them.
3. Feedback ingestion depends on Claude remembering to read a file. No hook injects it.

### Good at / bad at

Good at: one stable tab that live-reloads, clickable A/B/C choices, mockups in a themed frame, safe-by-default auth, cheap per screen.

Bad at: a long-lived background process (reaped on Codex and Windows, hence foreground modes at `start-server.sh:97-107`), remote/SSH sessions need port forwarding or a `0.0.0.0` bind, the user must still type in the terminal to hand control back, the screen-per-file history has no index or navigation, and the logo beacon is on by default.

## 4. Pocock HTML pages

| | Architecture report | Logic prototype | UI prototype |
|---|---|---|---|
| Output | One self-contained `.html` in `$TMPDIR` (fallback `/tmp`, `%TEMP%`), `architecture-review-<timestamp>.html` | One self-contained `.html`, double-click to open | Variants inside the real app route, `?variant=` param |
| Ref | `improve-codebase-architecture/SKILL.md:39` | `prototype/LOGIC.md:35-37` | `prototype/UI.md:18-31`, `:56-90` |
| Libraries | Tailwind Play CDN `https://cdn.tailwindcss.com` and Mermaid ESM `cdn.jsdelivr.net/npm/mermaid@11` (unpinned minor), `securityLevel: "loose"` | None. Plain HTML/CSS/JS inline, "no framework, no bundler, no server" | The project's own stack |
| Ref | `HTML-REPORT.md:3`, `:13-17`, `:100` | `LOGIC.md:37`, `:66` | `UI.md:51` |
| Open | `open` / `xdg-open` / `start`, then print the absolute path | "Send them the file, or open it for them" | Surface the URL and variant keys |
| Ref | `SKILL.md:39` | `LOGIC.md:54` | `UI.md:94-96` |
| User response | In the terminal: "Which of these would you like to explore?" | In the terminal, after clicking through | In the terminal: "header from B with sidebar from C" |
| Ref | `SKILL.md:60` | `LOGIC.md:54` | `UI.md:96` |

Content rules worth adopting: diagrams carry the weight, one-sentence problem and solution, wins at 6 words or fewer, before/after side by side at about 320 px tall, one accent colour plus red and amber, badges for recommendation strength, a top-recommendation card linking to its candidate (`HTML-REPORT.md:36-104`). Logic pages put the state panel and free-play buttons above guided scenario tabs (`LOGIC.md:41-48`).

Weaknesses: needs network for Tailwind and Mermaid (unstyled and undiagrammed offline); Tailwind Play CDN is a runtime JIT not meant for production; Mermaid `loose` lets diagram labels carry HTML and click handlers; Claude writes the full document each time, CSS scaffold included; no two-way channel; every run opens a new tab.

## 5. pstack and addy

- **pstack** has no HTML, canvas or diagram output. Mermaid appears only in its own docs (`PS/docs/guide/02-poteto-mode.md:9`, `04-design.md:33`, `07-overnight.md:44`). Relevant mode mechanism: `PS/skills/poteto-mode/SKILL.md:1-9` frontmatter carries `mode: true`, `icon: crown`, `color: yellow`, and a `reminder:` line ("New task? Playbook match or rigor needed -> apply /poteto-mode. Casual turn or user opts out -> don't."). These are Cursor plugin fields (`PS/.cursor-plugin/plugin.json`); Claude Code ignores them. The pattern of a one-line per-turn reminder that also says when not to apply the mode is worth copying into a UserPromptSubmit hook.
- **addy** has no HTML or visual output (`grep -rniE "\.html|canvas|mermaid|diagram" AD` finds only eval fixtures and a lint regex). Its `AD/hooks/session-start.sh:1-33` injects a meta-skill as SessionStart `additionalContext` and is deliberately not wired on Claude Code, because Claude Code already routes skills by description. That supports keeping per-session injection to the active mode's rules only.

## 6. Proposed design for three modes

### 6.1 State model: two axes, three presets

Modes combine, so store two fields, not one name.

| Field | Values | Default |
|---|---|---|
| `voice` | `normal`, `terse` | `normal` |
| `surface` | `chat`, `html`, `auto` | `auto` |

| Preset the user types | voice | surface |
|---|---|---|
| `terse` (the caveman-like mode) | terse | chat |
| `html` | normal | html |
| `auto` / `normal` | normal | auto |
| `html terse` | terse | html |

HTML pages are always written in plain prose regardless of `voice`. Caveman's own rules exempt anything persisted outside chat (its `SKILL.md` "When to break the rules" item 5). `voice` governs chat only.

### 6.2 Storage

| Scope | Path | Holds |
|---|---|---|
| Per session | `${CLAUDE_PLUGIN_DATA:-$CLAUDE_CONFIG_DIR/.<plugin>}/sessions/<session_id>.json` | `{voice, surface, portal:{url,port,pid}, unreadAnswers}`. Keyed by the `session_id` every hook payload and the statusline stdin carry |
| Per project default | `.<plugin>.json` in the repo, walked up from the session `cwd` | `{voice, surface}`, including an opt-out |
| Global default | `~/.config/<plugin>/config.json`, overridden by env `<PLUGIN>_MODE` | `{voice, surface}` |
| Pages | `<project>/.<plugin>/pages/<session_id>/` if the project dir is writable and gitignored, else `$TMPDIR/<plugin>/<session_id>/` | Rendered pages, `answers.jsonl`, `index.json` |

Resolution order matches `caveman-config.js:148-166`: env, repo, user, built-in. Check whether `CLAUDE_PLUGIN_DATA` is provided by the host before relying on it (open question for cc-plugin-mechanics).

### 6.3 Switching

- Skill `/mode` with `disable-model-invocation: true` and one argument: `terse`, `html`, `auto`, `normal`, `html terse`, `status`, `off`. The UserPromptSubmit hook parses the `<command-name>`/`<command-args>` envelope (`caveman-mode-tracker.js:165-189`) and writes state, so the switch does not depend on the model obeying.
- Natural language, prompt-initial or clearly imperative only: "html mode", "show me in the browser from now on", "terse mode", "be terse", "back to normal", "stop html". Reuse the negation and question guards from `caveman-parse.js:107-170`. Never act on text inside quotes or another command's envelope.
- `status` reports and changes nothing.

### 6.4 Enforcement

| Hook | Fires | Injects |
|---|---|---|
| SessionStart | `startup`, `clear` re-derive the default. `compact`, `resume`, `fork` read stored state | Rules for the active preset only: terse ruleset (400 to 600 tokens) if `voice=terse`, html contract (300 to 500 tokens: when to publish, page types, how to reply in chat, where answers arrive) if `surface` is `html` or `auto`. Nothing for `normal`+`chat` |
| UserPromptSubmit | Every prompt | (1) Switch parsing and full new ruleset on a real switch. (2) One-line reminder only when not in the default preset, about 40 tokens. (3) Unread browser answers from `answers.jsonl` as `additionalContext`, then mark them read. Skip entirely on `<scheduled-task` and for headless SDK entrypoints |
| SubagentStart | Each subagent | `voice` only. Subagents never publish pages; they return text to the parent, which publishes |
| Statusline | Each render | Badge from the session file: `[TERSE]`, `[HTML]`, `[HTML+TERSE]`, nothing for default. Offer a snippet once; never overwrite an existing `statusLine` |

Output styles are a poor fit. They live in settings files (`outputStyle` in project or user settings), so a switch leaks into every other session in that project, and they replace system-prompt sections rather than toggling per session. Caveman does not use them. Hooks are the right mechanism.

### 6.5 `html` architecture options

| | (a) Local portal server | (b) Static files | (c) Hosted page via host tool (claude.ai Artifact) |
|---|---|---|---|
| Two-way | Yes. Clicks and form answers POST to the server, land in `answers.jsonl`, and the UserPromptSubmit hook injects them on the next prompt. The browser still cannot wake Claude | No. Buttons can copy a structured reply to the clipboard for pasting into the terminal | Partial. Comments on a watched artifact reach the session. A page database can hold choices that Claude reads with `ArtifactData` |
| Live update, one tab | Yes (SSE or WebSocket reload; sidebar of all session pages) | No. A new tab per page | Yes. Republishing updates the same URL |
| Offline | Yes, with vendored assets | Yes, with vendored assets; no with pocock's CDNs | No |
| Security | Loopback bind, random key, Origin check, strict CSP possible. A listening port exists for the session | Nothing listens. `file://` pages; Mermaid must use `securityLevel: "strict"` | Content leaves the machine to claude.ai, private by default. Not acceptable for code or data the user treats as sensitive |
| Setup cost | Node process, port, lifecycle, reaping on some harnesses | None | None when the tool exists; absent on other harnesses |
| Token cost | Content fragment only; CSS, JS, frame stay on disk | Content only if a renderer wraps it; full document otherwise | Full HTML per publish |
| Remote/SSH/web session | Needs port forwarding or a non-loopback bind | File lands on the remote host; user cannot open it | Works on any device with the URL |

**Recommendation.** (a) as the primary transport for local sessions, (b) as the automatic fallback, (c) as an explicit opt-in target.

- (a) Vendor `server.cjs` (MIT, keep its copyright notice) and change it: drop the logo beacon, add a portal index and sidebar, replace "newest file wins" with a page list keyed by id, keep answers per page id instead of deleting them on each push, fix the `choice`/`value` mismatch, add CSP `default-src 'self'; script-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'`, serve vendored Mermaid from the plugin dir. Start it lazily on the first page, not at session start.
- (b) Fallback when node is missing, the server fails to start, or the session is remote without a forwarded port (`SSH_CONNECTION` set). The same renderer writes a self-contained file with inline CSS and prints the path.
- (c) Only when the Artifact tool is present and the user sets `html target=hosted` for the session. Required for remote and web sessions where (a) and (b) cannot reach the user's browser. Confirm once per session that pages will be uploaded.

Content path for (a) and (b): Claude writes a content fragment (design-system classes, Mermaid in `<pre class="mermaid">`) with its Write tool. A small renderer adds the frame, CSS, Mermaid loader and answer wiring. The model never pays for boilerplate.

### 6.6 Page contents per output type

| Type | Sections | Interactive parts |
|---|---|---|
| Spec / design | Header (problem, goals, non-goals), context map (Mermaid flowchart), requirements table (id, requirement, acceptance check), design sections with sequence or ER diagram, alternatives considered, risks, open questions, decision log | Answer box per open question; approve / request changes |
| Plan | Summary, phase timeline, task table (id, file, change, test command, depends on, status), dependency graph, file-by-task touch matrix, risks and rollback | Approve plan; flag a task |
| Review findings | Verdict banner, counts by severity, findings grouped by file: severity badge, `path:line`, failing scenario, smallest fix, excerpt or diff; clean classes as one line each | Severity filter; accept / dismiss per finding |
| Debug report | Symptom, repro steps, timeline, hypotheses table (hypothesis, evidence for, evidence against, status), causal chain diagram, root cause at `path:line`, fix, verification commands with output, blast radius | Confirm repro; pick a fix option |
| Decision / question | The question, context, 2 to 4 option cards (summary, pros, cons, cost, risk), comparison matrix, recommended option badge | Choose buttons, "other" free-text box |
| Status dashboard | KPI tiles (tasks done of total, tests, PRs, blockers), board by status, current step, recent events log, links | Auto-refresh via the portal |

Shared design system (one CSS file, inlined by the renderer):

- Tokens on `:root` with a `prefers-color-scheme: dark` override: background, surface, text, muted, border, one accent, success, warning, danger. System font stack plus a monospace stack.
- Components: page header (title, type badge, status, timestamp, repo, branch), sticky table of contents, section card, callouts (info, warning, risk, decision), severity badges, tables, code block with `path:line` caption, diagram card, option card, KPI tile, progress bar (`role="progressbar"` with `aria-valuenow/min/max`), timeline, key-value grid, diff block.
- Rules: plain prose, one accent colour, diagrams before paragraphs, `prefers-reduced-motion` respected, visible non-colour focus ring, no remote assets.

### 6.7 How `auto` decides

`auto` stays in chat unless every condition in one row holds.

| Promote to a page when | Threshold |
|---|---|
| Output type is spec, plan, debug report or status dashboard | Over about 40 lines or 600 words |
| Review findings | 5 or more findings, or findings across 3 or more files |
| Decision | 3 or more options, or any option needs a diagram or mockup |
| Any output | Needs a diagram, or a table over about 10 rows |

In `auto`, write the page but do not open the browser. Chat gets at most 3 lines: what the page shows, the link or path, and the decision needed. In `html`, open or push to the portal and follow the same 3-line chat rule. Never repeat page content in chat. Short answers, clarifying questions and confirmations stay in chat in every mode. Irreversible-action confirmations and security warnings always appear in chat in full sentences, even in `html`.

### 6.8 Open questions for other agents

1. Does Claude Code set `CLAUDE_PLUGIN_DATA` for plugin hooks, and is it per plugin? (cc-plugin-mechanics)
2. Can a plugin push a message into a running session (so a browser answer can wake Claude), or is next-prompt injection the limit? (cc-modes-docs)
3. Does a SessionStart hook still fire with `source: "compact"` on auto-compaction in the current release? Caveman depends on it (`caveman-activate.js:207-245`).
