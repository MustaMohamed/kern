exec(open('/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/specsync.py').read())
import re
spec=open(SPEC).read()
def rep(a,b,count=1):
    global spec
    c=spec.count(a)
    assert c==count,(a[:80],c)
    spec=spec.replace(a,b)

# remap support: self-review inserted step 4
_orig_build=build
def build_remap(name, sec, extra, remap):
    tags,sub=old_tags(sec)
    tags2={n:tags.get(remap.get(n,n),'') for n in range(0,40)}
    out=['**4. Steps**']; si=0
    for l in new_steps(name):
        m=re.match(r'^(\d+)\. (.*)$',l)
        if m:
            n=int(m.group(1)); body=short(m.group(2))
            if n==0: out.append('0. Defer (A6).'); continue
            tg=tags2.get(n,'') if remap.get(n,n) is not None else ''
            add=extra.get(n,'')
            if add: tg=(tg[:-1]+'; '+add+']') if tg else '['+add+']'
            out.append(f'{n}. {body}'+(f' {tg}' if tg else '')); continue
        m=re.match(r'^(\s+)- (.*)$',l)
        if m:
            tg=sub[si] if si<len(sub) else ''; si+=1
            out.append(f'{m.group(1)}- {short(m.group(2))}'+(f' {tg}' if tg else '')); continue
        out.append(short(l))
    return '\n'.join(out).rstrip('\n')
def steps_section(cid,name,extra,tail='',remap=None,gate_tag=None):
    global spec
    i=spec.index(f'### {cid}. `{name}`'); j=spec.find('\n### ',i+5); j=len(spec) if j<0 else j
    sec=spec[i:j]
    a=sec.index('**4. Steps**'); b=sec.index('**5. Outputs')
    ns=build_remap(name,sec,extra,remap or {})
    if gate_tag:
        for g,t in gate_tag: ns=ns.replace(g, g+' '+t,1)
    body=ns+'\n\n'+(tail+'\n\n' if tail else '')
    spec=spec[:i]+sec[:a]+body+sec[b:]+spec[j:]

RF='Red flags: the skill ends with a `## Red flags` table (`| Thought | Reality |`, 2 to 6 rows); lint rule 9 requires it for discipline skills.'

# ---------- A3 scripts
rep("| `wt-new <slug> [--detach] [--base <ref>]` | `git fetch origin <base>`, `git worktree add` off `origin/<base>` under `worktree.dir`, copies files named in `.worktreeinclude`, runs `worktree.setup`, prints the path | 0; 2 | [SP using-git-worktrees:51-140] adapted |",
"| `wt-new <slug> [--detach] [--base <ref>] [--branch <name>]` | `git fetch origin <base>`, `git worktree add` off `origin/<base>` under `worktree.dir`, copies files named in `.worktreeinclude`, runs `worktree.setup`, prints the path. A `branch.pattern` placeholder it cannot fill needs `--branch` | 0; 2 | [SP using-git-worktrees:51-140] adapted |")
rep("| `wt-diff <wt> <from-tree> [<to-tree>] [--out <f>]` | Review package: name-status, stat, `git diff -U10 <from> <to>`; prints the file path, the changed file list and `<to-tree>` | 0; 3 empty diff; 2 error | [SP subagent-driven-development/scripts/review-package:25-50] adapted |",
"| `wt-diff <wt> <from-tree> [<to-tree>] [--out <f>] [--allow <path>]... [--allow-file <f>]` | Review package: name-status, stat, `git diff -U10 <from> <to>`, and a `.patch` beside it; prints the file path, `<to-tree>` and the changed file list. With an allow list, each changed path outside it is named and the exit is 4 (the package is still written) | 0; 3 empty diff; 4 outside the allowed paths; 2 error | [SP subagent-driven-development/scripts/review-package:25-50] adapted |")
rep("| `wt-apply <patch> <dst-wt>` | `git apply --check`, then `git apply` | 0; 3 conflict | new |",
"| `wt-apply <patch> <dst-wt>` | `git apply --check`, then `git apply` | 0; 3 conflict | new |\n| `wt-audit [--days N]` | Read-only bucket list of kern worktrees: merged, open PR, closed PR, uncommitted, committed, empty, with evidence | 0; 2 usage | [PB worktree-cleanup] |")
rep("| `task-brief <plan> <N>` | Extracts task N's text to `briefs/task-N.md` | 0; 2 | [SP subagent-driven-development/scripts/task-brief] |\n| `task-start` / `task-done <N> <tree> -- <cmd>` | Ledger lines; `task-done` writes `complete` only when `<cmd>` exits 0 | 0; command's code | [SP executing-plans/scripts/task-done:39-52] |",
"""| `ledger-open <plan> [<dir>]`, `ledger-open --summary <dir>` | Opens the plan's ledger (the slug is the plan's basename, lowercased), or exits 2 when the plan lacks `status: approved` and `approved: <date>, "<quote>"` or the dir holds another plan's ledger; records the main checkout's state. `--summary` lists the Decision, parked, Preflight and deferred-minor lines and says whether the main checkout changed | 0; 2 | [SP subagent-driven-development:141-147,473-482; SP sdd-workspace:6-9] |
| `task-brief <plan> <N> <ledger-dir>` | Extracts task N's text plus the Global Constraints to `briefs/task-N.md` | 0; 2 | [SP subagent-driven-development/scripts/task-brief] |
| `task-start <ledger> <N> <tree>` | Appends the start line | 0; 2 | new |
| `task-review <ledger> <N> <tree> <round> <spec> <quality> [--minor <text>]...` | Appends the review line and one deferred-minor line per `--minor`; at most 3 rounds | 0; 2 | [SP subagent-driven-development:361-364] |
| `task-done <ledger> <N> <wt> <tree> [--probe <patch>] -- <cmd>` | Writes `complete` only when the latest review approved this tree, the worktree still snapshots to it, `<cmd>` exits 0 and, with `--probe`, the test fails with the change reversed; records the last output line | 0; 2 refused; the command's code | [SP executing-plans/scripts/task-done:39-52] |
| `brief-check <file>` | A worker brief has its nine fields, none empty, and VERIFY starts with `wt-check` | 0; 1; 2 usage | [PB orchestrate:56] |
| `plan-check <file>`, `--graph <plan>`, `--files <plan> <N>` | Lints a plan or spec: structure, placeholders, approval with the user's words, Blocked-by order for tasks sharing a file or a `shared_services` entry, each Consumes after its Produces, every acceptance number covered. `--graph` prints overlaps and waves; `--files` a task's paths | 0; 1; 2 usage | [PB check-plan.mjs:1-190] |
| `recall-sessions [--days N] [--topic T]` | This project's sessions (worktree sessions included), newest first, and with `--topic` its matching prompts; never another project's | 0; 2 usage | [LOC recall "Where the records are"] |
| `floor-scan <diff>` | G7 as a script: suppressions, skipped or deleted tests, removed assertions, stubs, debug prints, and a lowered bar (coverage, strict typing, a lint rule, a CI step, `ratchet.<metric>`) | 0; 1 hits; 2 not a diff | [ADR floor-guard:7-13] |
| `claim-check <wt> <diff>` | G9: unknown commit ids and absolute claims | 0; 1 | new |
| `probe [--exclude-tests] <wt> <patch> -- <cmd>`, `probe --mutate <file:line> <wt> -- <cmd>` | G10: fail-then-pass on a fork with the change (tests excluded) reversed; or one inverted condition on a fork. Inconclusive, never ok, when the command cannot run | 0; 1; 3 inconclusive | [SP verification-before-completion:82-86] |""")
# ---------- A5 keys
rep("| `lessons` | none: proposals stay in chat | none | self-review |",
"| `lessons` | none: proposals stay in chat | none | self-review |\n| `ratchet.<metric>` | none | none | floor-scan |")
rep("| `model.implementer`, `model.reviewer`, `model.final_review`, `model.investigator`, `model.miner` | `sonnet`, `sonnet`, `opus`, `sonnet`, `haiku` | none | execute-plan, parallel-work, recall |",
"| `model.implementer`, `model.reviewer`, `model.final_review`, `model.investigator`, `model.miner` | `sonnet`, `sonnet`, `opus`, `sonnet`, `haiku` | none | execute-plan, parallel-work, self-review, define, plan, diagnose, recall |")
# ---------- A9
rep("`visual` ships in M4. A step that says \"page when installed\" checks `KERN/skills/visual/SKILL.md`. Absent: stay in chat and say once \"visual pages not installed\".",
"`visual` ships in M4. A step that says \"page when installed\" offers a page only when kern's `visual` skill is installed; otherwise it stays in chat and says once \"visual pages not installed\". No skill names the visual skill's path, which does not exist before M4 (lint rule 4 would fail).")
# ---------- A10
rep("Investigator `sonnet`. Transcript miners `haiku`. Each dispatch names its model explicitly [SP subagent-driven-development:184-219]; `model.<role>` overrides.",
"Investigator `sonnet`. Transcript miners `haiku`. Each dispatch names its model explicitly, the investigator's included (`model.investigator`) [SP subagent-driven-development:184-219]; `model.<role>` overrides.")
# ---------- B1 item 2
i=spec.index('2. Natural language: a switch phrase alone on the prompt\'s first line')
j=spec.index('\n',i)
old=spec[i:j]
new=old.replace("2. Natural language: a switch phrase alone on the prompt's first line (\"terse mode\", \"go terse\", \"back to normal\", \"html mode\", \"stop html\"); with anything else on that line, a negation and a question included, nothing switches.",
"2. Natural language: a switch phrase alone on the prompt's first non-blank line (\"terse mode\", \"go terse\", \"terse voice\", \"terse mode on\", \"back to normal\", \"html mode\", \"stop html\"). A leading \"please\", \"ok\" or \"okay\", a trailing mix of \"please\" and \"now\", repeated final \".\" or \"!\", and extra spaces are allowed; with anything else on that line, a negation and a question included, nothing switches, and a first line over 200 characters never switches.")
assert new!=old
spec=spec[:i]+new+spec[j:]
open(SPEC,'w').write(spec)
print('A,B done')
