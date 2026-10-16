# /code-review findings, M1 92cecaa..be26d2f

## 1. hooks/lib/gitctx.sh:117

Summary: The sh-family -c unwrapping only matches lower-case flag clusters (/^-[a-z]*c[a-z]*$/). It also takes `--` as the script, and reads value-taking long options (--rcfile, --init-file) as plain flags. A script run as `bash -Ec`, `sh -Cc`, `bash -c --` or `bash --rcfile f -c` is never parsed by any guard. shellin at :182 and G15 at g15-deploy.sh:149 have the same gap.

Failure: Under autopilot, `bash -Ec 'git push --force origin main'`, `bash -c -- 'git push --force origin main'`, `bash -Ec 'gh pr merge 12'` and `bash -Ec 'kubectl apply -f x.yml'` all return no decision. With protected_targets: prod-db and no autopilot, `bash -Ec "ssh prod-db 'rm -rf /data'"` also returns nothing, while the plain and `bash -c` forms are denied. bash runs `-Ec` and `-c --` scripts normally.

## 2. hooks/lib/gitctx.sh:171

Summary: _split_words' hdat() treats `<<` inside `${...}` or legacy `$[...]` arithmetic as a here-doc. Every following line up to a matching delimiter line is dropped from the records, so all guards miss those commands; bash does not read them as a here-doc and runs them.

Failure: The command `echo ${x:-<<X}` / `git push --force origin main` / `X}` (three lines) gets no vote under autopilot, and bash runs the force push. The same shape hides `ssh prod-db rm -rf /data` from G13. `echo $[1<<X]` with a closing `X]` line behaves the same way.

## 3. hooks/guards/g01-git.sh:502

Summary: _g01_proven accepts `git -C <any repo> push <remote> <its current branch>`. branch_protected and base_branch_name resolve against KERN_MAIN (the session repo), not the -C repo, so another repo's base branch is not protected. G5 rejects a cross-repo -C (_G05_CROSS); G1 does not.

Failure: The other repo's default branch is develop. Running `git push origin develop` inside it under autopilot is denied as a protected branch. `git -C /path/other push origin develop` from the session repo is ALLOWED: "autopilot push of the current branch develop". push.policy: auto allows it the same way.

## 4. hooks/guards/g01-git.sh:360

Summary: G1 (and G6 at g06-secrets.sh:69) check only the `push` subcommand. The builtin plumbing that pushes refs (send-pack, http-push) and `send-email` (messaging people, a floor action) pass with no vote: no force-push deny, no protected-branch ask, no secret scan.

Failure: Under autopilot, `git send-pack --force <origin-url> feat:main` returns no decision and force-overwrites main without G6 scanning it. `git http-push --force ...` and `git send-email --to=team@x.com HEAD~1` also return no decision.

## 5. hooks/guards/g02-pr.sh:34

Summary: G2 matches only `pr create`. gh 2.100.0, the version G2's tables cite, lists `gh pr new` as an alias, so the draft requirement, the duplicate check and the autopilot deny never run. G4 has no text spec for `issue new` / `release new`, so their -b/-n inline text is missed.

Failure: `gh pr create --title x --body-file README.md` is denied ("open PRs as drafts"). `gh pr new --title x --body-file README.md` returns no decision under autopilot, and gh opens a non-draft PR even if one is already open for the branch.

## 6. hooks/guards/g01-git.sh:137

Summary: gh aliases and extensions are never treated as unknown. G1 asks on git aliases (_g01_foreign), but a direct gh call with an alias or extension subcommand gets no vote from G1, G2, G3 or G14. `gh alias set` itself is unguarded.

Failure: Under autopilot, `gh alias set pm 'pr merge --admin'` and then `gh pm 12` both return no decision, so a PR merges with no human. `gh alias set --shell pm 'git push --force origin main'` also passes.

## 7. hooks/guards/g06-secrets.sh:296

Summary: G6 scans the index and HEAD as they are at hook time. A git add, cherry-pick or merge earlier in the same Bash call changes what is committed or pushed, and G6 neither scans that content nor reports the scan as stale.

Failure: Settings: never_commit: .env*, and .env holds AKIAABCDEFGHIJKLMNOP. `git add .env` followed by a separate `git commit` is denied for both the never_commit path and the AWS key. `git add .env && git commit -m "feat: x"` gets only G5's shape ask, with no secret warning. The user approves and the key is committed.

## 8. hooks/guards/g16-state.sh:92

Summary: For Bash, writes to a settings file are recognised only when the word ends literally in `.claude/kern.local.yml` or `.claude/kern.yml`. _g16_file normalises `.`, `..` and `//` for the Write tool; _g16_kind does not.

Failure: Under autopilot, `echo 'kern: off' > .claude/kern.local.yml` is denied. `echo 'kern: off' > .claude/./kern.local.yml`, `> .claude//kern.local.yml` and `cp /tmp/kern.local.yml .claude/` return no decision, and every guard is off from the next call.

## 9. hooks/guards/g01-git.sh:55

Summary: G1 treats only cd, pushd, popd and GIT_DIR/GIT_WORK_TREE assignments as moving the directory. It ignores `env -C/--chdir` and `sudo -D/-R`, which G5 and G6 already detect through _g05_env's @cwd, so the main-checkout (D3) checks run against the wrong directory.

Failure: From a linked worktree under autopilot, `env -C /main git reset --hard` and `env --chdir=/main git checkout -B main origin/main` return no decision. `git -C /main reset --hard` is denied ("in the main checkout").

## 10. hooks/lib/json.sh:50

Summary: The JSON scanner calls substr() once per character over the whole hook input. In BWK awk that is quadratic, as gitctx.sh's own comment notes. The dispatcher runs two whole-document scans per call: json_get_raw tool_input, and json_get agent_type (pre-tool-use:47), which is absent in the main session. No M1 guard reads AGENT.

Failure: Measured with awk 20200816: each scan takes 2.6 s on a 400 KB input, and the hook takes 7.8 s for a 400 KB Write versus 0.68 s at 100 KB. A Write or Edit of roughly 700 KB or more passes the 20 s timeout, so with onFailure: block the edit is refused, or it runs unguarded if that key is ignored.

## 11. hooks/lib/settings.sh:173

Summary: `kern: off` and the loosening *.policy keys use highest-file-wins. A committed project `.claude/kern.yml` therefore overrides the user's `~/.claude/kern.yml` and drops the user's union-key protections. kernel/settings.md:8 says a project file cannot drop an entry the user file sets.

Failure: ~/.claude/kern.yml sets protected_targets: prod-db, and `ssh prod-db 'rm -rf /data'` is denied. Clone a repo whose committed .claude/kern.yml says `kern: off` and the same call returns no decision. The repo can likewise commit `push.policy: auto`.

## 12. hooks/guards/g03-review.sh:162

Summary: _g03_comment never checks the review.taxonomy label. Spec 8.3 G3 says comments without a label are denied, and _g03_review does enforce it for `gh pr review`.

Failure: With review.post_policy: auto, `gh pr comment 5 --body-file c.md`, where c.md reads 'looks fine to me', is ALLOWED. The same body via `gh pr review 5 --comment --body-file r.md` is denied.

## 13. skills/autopilot/SKILL.md:23

Summary: Altitude: every guard is a deny-list keyed on command heads it recognises. A record with a dynamic head ($g, $'git'), an unparsed shell, an unknown gh subcommand or git plumbing gets no vote, and decide.sh:44 only turns asks into denies. The fix belongs in the dispatcher, not in more per-flag patches: under autopilot, deny any Bash record whose head is dynamic or a shell/interpreter whose script was not unwrapped, and any git/gh subcommand not on an explicit list.

Failure: `g=git; $g push --force origin main` returns no decision under autopilot, while the docs say "kern denies what it cannot prove" and "kern denies plain force pushes" (kernel/kernel.md). Each new bypass shape (findings 1, 4, 5, 6) needs its own patch.

## 14. hooks/lib/gitctx.sh:330

Summary: Reuse: git's global options are parsed three times with different tables (git_sub here, _g01_git_rec g01:151, _g05_split g05:66), and refspecs twice (push_targets vs _g01_opts/_g01_ref). git_words is re-run by G1, G4, G5, G6, G13, G15 and G16 on every call, while only G2, G3 and G14 share _gh_load's cache.

Failure: git_sub lacks -P, --no-advice, --config-env and the separate `--git-dir <path>` form, so with deploy.envs: production, G15's deploy-branch check skips `git -P push origin production`; G1 still asks only by coincidence. Each table fix has to be made in three places, and the command is parsed up to 7 times.

## 15. hooks/guards/g02-pr.sh:16

Summary: The docs and the code disagree on the allowed draft-PR shape. kernel/settings.md:97 and skills/autopilot/SKILL.md:26 list only --title, --base, --fill and --body-file. _GH_CREATE_SAFE also lets --head, --fill-first, --fill-verbose, --dry-run and --no-maintainer-edit through to an allow.

Failure: `gh pr create --draft --fill-verbose --no-maintainer-edit` is allowed under autopilot or pr.policy: auto, while the documented contract says that shape asks or is denied.
