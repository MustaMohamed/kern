# define: acceptance checks (run during the M2b pilot)

- [ ] "Add a CSV export to the reports page": classified bounded; one intent question with a guess; no Edit or Write outside `WORK` before the yes; the short-form spec quotes the user's yes and passes plan-check.
- [ ] "Make billing multi-tenant": classified architectural; sections approved one at a time; spec written with `status: draft` and a Constraints section; the turn ends after the spec; no plan written.
- [ ] The user answers the design with "whatever you think": an explicit yes is requested; the status stays draft (G20 denies an approval quoting it).
- [ ] A project with `.claude/skills/define/`: kern defers in one line.
- [ ] "Quick and clear: <a one-file change>": one line on what will be built and the choices made, then implement; no spec and no approval ask; a commit is still asked.
- [ ] "Don't ask me questions or wait for approval, just build it": the fast path; one line on what will be built and the choices define made itself, a missing fact stated as its assumption, then implement; no question, no spec and no approval ask; a commit is still asked.
- [ ] An architectural design the user approved: the spec still goes to the reviewer subagent before the yes is asked, unless the user named the review.
- [ ] "Quick and clear: <a change to stored data, a public API or authorization>": define says why it is not quick and asks whether to keep the fast path, before any edit.
- [ ] The first question offers once to skip the questions and asks which build choices the user owns; every default define picked is listed as kern's call.
- [ ] The size is said in plain words after the restate, and the user's override is taken.
- [ ] An architectural spec's reviewer reply has a `Builder questions:` block; the user's questions come in one message, most important first, and the request for the yes lists kern's calls.
