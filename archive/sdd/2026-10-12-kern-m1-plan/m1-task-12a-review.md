### Spec Compliance

- ✅ Long options: `hooks/lib/gitctx.sh:14-19` has env `--chdir --unset --split-string --argv0`, the 10 sudo options (+`--chroot`, D1), nice `--adjustment`. `--split-string` is read like `-S` (`:62-67`, `:69`).
- ✅ Hidden git: `hooks/guards/g01-git.sh:63`, `:79-117`. The read-only set at `:68` is the brief's 19 names. The reason text matches. Own commands come from `_G01_GIT_CMDS`, not a copy.
- ✅ Hidden gh: `hooks/guards/g02-pr.sh:21-23`, `:45-71`. It reads past `-R`/`--repo` and its value. The group list matches gh 2.100.0's `gh help`, minus browse, search and status.
- ✅ `NAME+=value`: `gitctx.sh:55`, `g05-commit.sh:122-130`, G1 `moved` at `g01-git.sh:55`. Wrapper names in any case: `gitctx.sh:58`, `g05-commit.sh:131-132`.
- ✅ Every test the brief names is present: `gitctx.bats:319`, `g01-git.bats:508-583`, `g02-g04-gh.bats:446-468`, `g05-g06-commit.bats:961`. The diff touches exactly the 8 files.
- ✅ Fix 79bb928 follows the C1 (a) ruling, line `:92-95`.
- ⚠️ The diff cannot show the suite result or the implementer's RED runs; I did not re-run them.
- ⚠️ Outside this diff, for a ruling: the Claude Code shell snapshot (`~/.claude/shell-snapshots/`) defines 248 aliases on every call. Among them are `gpf!='git push --force'` and `grhh='git reset --hard'`. These calls hold no word git, so no guard sees them. The accepted "alias set by an earlier call" class is wider than its wording suggests.

### Strengths

- No new allow path. I probed 50 variants of the three proven shapes at d87d2a3 and 79bb928 under autopilot. They were wrapped, assigned, case-changed, or carried a hidden git or gh in a later record. The allows are the same in both: the plain push, `| grep git`, `| cat`, `| grep -c gh`. Every other variant is deny. Examples:
  - `git push origin <cur> | xargs git push --force origin main`
  - `X+=1 git push origin <cur>`, `Env git push origin <cur>`
  - `git commit -m 'CDS-2465: x' | SUDO git push origin main`
  - `<draft> | Env gh pr merge 1`, `GH_REPO+=o/r <draft>`

  All three allow paths still need record 0 to start with `git ` or `gh ` (`g01-git.sh:483`, `g05-commit.sh:326`, `g02-pr.sh:269`). The new rules vote only ask or deny.
- The fail-closed rule also covers unlisted wrapper options: `sudo -c staff git push ...`, `nice --adj 5 git push`.
- The git global-option skip list matches real git 2.54. `-C.` and `--shallow-file=x` are both "unknown option", so leaving them out is correct.
- Here-doc bodies and multi-line `-m` messages add no votes. `cat > notes.md <<'EOF' ... git push --force ... EOF` gets none.

### Issues

**Critical:** none.

**Important**

1. `g01-git.sh:88-117`: a hidden git can still be steered to push by config set in the same command. The alias fix only checks a `-c`/`--config-env` value that names `alias.*`. Real git 2.54 in a throwaway repo ran `push` for each of these routes:
   - `git -c help.autocorrect=immediate psuh --dry-run origin <cur>`
   - `-c include.path=<file with [alias] p = push> p`
   - `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.p GIT_CONFIG_VALUE_0=push git p`
   - `GIT_CONFIG_PARAMETERS="'alias.p=push'" git p`

   Hook decisions, the same at d87d2a3 and 79bb928, with autopilot on and off:
   - `caffeinate git -c help.autocorrect=immediate psuh --force origin main`: **none**
   - `caffeinate git --config-env=help.autocorrect=V psuh --force origin main`: **none**
   - `caffeinate git -c include.path=/tmp/a.cfg p --force origin main`: **none**
   - `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.p GIT_CONFIG_VALUE_0=push caffeinate git p --force origin main`: **none**
   - `GIT_CONFIG_PARAMETERS="'alias.p=push'" caffeinate git p --force origin main`: **none**
   - `export GIT_CONFIG_PARAMETERS=...; caffeinate git p --force origin main`: **none**
   - `GIT_CONFIG_PARAMETERS="'alias.p=push'" git p --force origin main`: **deny** (`_g01_foreign`)

   Under autopilot the hidden form runs a force push to main. The direct form is denied. This is the one-command class the C1 (a) ruling meant to close; the "earlier call" limit does not cover it.

   Fix: set `al=1` for any `-c`/`--config-env` before the word. Also set it when the command text holds `GIT_CONFIG`, which needs the command or record passed to `_g01_hidden`. Cost: `caffeinate git -c color.ui=never log -1` asks, so its none case at `g01-git.bats:578` changes. A longer list of keys (help.autocorrect, include*, includeIf*) also works, but it is a list of dangerous keys and will miss the next one. Add the five probes above as tests.

**Minor**

2. `g02-pr.sh:21-23`: `_G02_GROUPS` leaves out cobra's aliases for the groups. gh 2.100.0 `gh help <group>` lists `cs`, `ext`, `extensions`, `rs`, `at`, `agent`, `agents`, `agent-tasks` and `skills`. Results:
   - `caffeinate gh codespace delete --all --force`: deny. `caffeinate gh cs delete --all --force`: none.
   - `caffeinate gh extension install o/evil`: deny. `caffeinate gh ext install o/evil`: none.
   - `caffeinate gh agent-task create "x"`: deny. `caffeinate gh agent create "x"`: none.

   The direct forms get none too, so this opens nothing that running gh directly does not. It is still a gap in the brief's "a gh command group" rule. Fix: add the 9 aliases.
3. Exec-path dashed git is not seen. Real git 2.54 runs `$(git --exec-path)/git-push` as push. These get none at d87d2a3 and 79bb928, under autopilot:
   - `/Applications/Xcode.app/Contents/Developer/usr/libexec/git-core/git-push --force origin main`
   - the same behind `caffeinate`
   - the same behind `env --ch sub`

   This is from before the task and outside the brief, which names basename `git`. It needs its own ruling or task, for example: a basename `git-<own command>` outside the read-only set asks.
4. `gitctx.sh:46`: `env -S` lines are split on blanks only. That also misses env's backslash escapes, not only the quotes ruling 258 accepts. macOS env runs `env -S'echo\_one\_two'` as `echo one two`. `env -S'git\_push\_--force\_origin\_main'` gets none under autopilot. Either widen the C3 ruling to "env -S quoting and escapes", or have G1 ask when an `-S` value holds `"`, `'` or `\`.
5. Long commands cost more (n=3): `echo` + 2000 × `git log` takes 625 ms at d87d2a3 and 798 ms now; 2000 × `gh x` takes 466 and 638 ms. The cost is linear; for the record only.

Cost, measured (n=20, twice, autopilot off, d87d2a3 / 79bb928):

| Command | d87d2a3 | 79bb928 |
| --- | --- | --- |
| `ls` | 138, 147 ms | 147, 139 ms |
| `grep -rn git .` | 138, 137 ms | 139, 139 ms |
| `rg 'gh pr'` | 137, 139 ms | 143, 147 ms |
| `brew install gh` | 140, 139 ms | 146, 143 ms |

The `rg 'gh pr'` and `brew install gh` rows include the one extra `_cmd_words` process. Everything is within the 10 ms budget. `_g01_hidden` is plain bash, and `_g02_hidden` returns before starting a process unless the text holds `gh` or `g<quote>…h`. Bash 3.2: `local w=()`, `+=` and the bracket-class patterns are all valid in 3.2. No `set -u` or errexit is in play.

False asks: I ran 60 ordinary commands under autopilot. All got none except the following:
- Accepted echo/man class: `tldr git push`, `man git commit`, `printf '%s\n' git push`, `echo gh pr create`, `rg gh pr`.
- Real git runs: `git branch | xargs git branch -D`, `docker run --rm -v "$PWD":/git alpine/git clone https://x/y.git`.

Every command on the lead's list gets none.

### Assessment

**Task quality:** Needs fixes. No allow path was added and the brief is met, but a hidden git still runs a force push under autopilot through same-command config (`-c help.autocorrect`, `-c include.path`, `GIT_CONFIG_*`), the class the C1 fix was meant to close.
