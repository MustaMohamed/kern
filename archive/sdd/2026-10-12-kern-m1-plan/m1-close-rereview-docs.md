# M1 close re-review: fix wave B text, judged against HEAD 08818e9

### Spec Compliance

Checks run: `node scripts/lint-skills.mjs` is clean, and `node --test tests/*.test.mjs` passes 69/69. The rendered kernel with long-settings is 3,802 chars from my temp repo; the length varies with the Main worktree path. A probe of `git push --force-with-lease origin main` ran through hooks/pre-tool-use, in a repo where main holds another author's commit.

Closed:
- ✅ Important 1. settings.md's `commit.convention` row matches g05-commit.sh:288-297. When the key is unset, G5 runs kern-detect. When detection finds nothing, G5 checks nothing. An explicit empty value turns the check off.
- ✅ Important 2. fix-a-run points to the new table and to contract.md, and design 8.3's G13 and G14 rows match the code. The G1 row is accurate except for one clause; see Important 1 below.
- ✅ Important 3 and 4, in the uncommitted plan edits. The CHANGELOG draft covers proven shapes, G13, G14, the hidden-git rule, the union lists and known limits, and moves the M0 line. Step 4 inserts after the `cwd_rc` check, and its Files list names all three files.
- ✅ Minors 1, 2, 4, 5, 6, 7, 8, 9, 10 and 12. Minor 11 is mostly closed; see Minor 4.

Checked and true at HEAD:
- The table rows for commit, push, draft PR, review post, gh issue and label, Linear, Notion and GitHub MCP. The sources:
  - G3's safe sets at g03-review.sh:8-11 and :150-169;
  - G14's verbs, number-only positionals and body file at g14-tracker.sh:200-250;
  - the Linear list at g14-tracker.sh:29.
- The footnotes on filters, G6 denials (g06-secrets.sh:230, :260) and G3 denials.
- The new Read-by cells and the union of the four list keys (settings.sh:58-80).
- Spec B2.5 matches prompt-submit:185 word for word.
- design §6.1 and §5.4, and the storage line.


### Issues

**Critical:** none.

**Important**

1. **The new floor sentence is false for protected branches, and the ask hides the force.** kernel.md's Autonomy line says kern denies "a lease push unless every commit is the user's". design 8.3's G1 row says the same: "denied otherwise". But g01-git.sh:587-593 asks on any push to a protected branch and returns before the ownership check at :595-600. The probe shows a lease push to main over another author's commit gets `ask` with the reason `kern G1: push to protected branch main`. The reason never says the push is a force push, on the branch most likely to be shared. Fix the code: run the ownership check for protected targets too, or at least name `--force-with-lease` in that reason. Then the text is true as written.

**Minor**

1. The settings.md intro says "kern asks for any other shape", and the lease row's auto column says "It asks". Several out-of-shape calls are denied in interactive mode too:
   - a plain force push;
   - a lease push over someone else's commits;
   - a PR that is not a draft;
   - a commit that fails its checks.

   Write "asks or denies".
2. settings.md's `<file>` definition leaves out that the file must not be a symlink. `_gh_file_ok` refuses one (g02-pr.sh, `[ ! -L "$f" ]`).
3. The Autonomy section is now 829 chars, against its 650 budget (design 4.2, ruling F9). The whole kernel is still under rule 7's 4,000 warning by about 190 chars. M2's eight rows (about +980) need the budget decision that ledger:396 already names.
4. Unslop leftovers in the changed files:
   - kernel.md:2, :31 and :34 still join clauses with semicolons;
   - the fix-a-run guard row drops a verb in "and its rule in kern's design spec";
   - the M1 plan (:1623) and the M2 plan's kernelRows fixture (:4268) still use the old header "When (observable)". `kernelRows` skips that line, so nothing breaks.
5. Two CHANGELOG draft details:
   - "about 90 tools" overstates G15. Its table has 51 rows and 76 command names.
   - "Git and gh behind a wrapper ask" is true only for git write commands outside `_G01_READ_ONLY`, and for gh groups other than help, version, status, browse and search. `env git status` gets no vote. Write "git write commands and gh behind a wrapper".
6. Plan Step 5 item 4 now checks only the kern.local.yml exclude. The old porcelain check would have caught a missing `.kern/` exclude. Add `git -C <P> check-ignore -q .kern/notes`.

### Assessment

**Task quality:** Needs fixes. Wave B closes every earlier finding. The one new sentence about lease pushes is false for protected branches, and the code behind it asks with a reason that hides the force.
