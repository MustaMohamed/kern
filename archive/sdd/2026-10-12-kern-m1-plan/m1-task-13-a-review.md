### Spec Compliance

I checked a fresh `git archive 32f5e4b` against every `Ruling: Task 13 unit A` line.

- ✅ (1), and the amendment. The allow path matches the family as a token, then the exact name on `_G14_LINEAR` or `_G14_NOTION` (`hooks/guards/g14-tracker.sh:26,29,115-135`). github is off the auto path, and its reason points to gh.
  - I re-ran the round-1 table of 130 names under `tracker.policy: auto`. 5 allow, all list names: Linear `save_issue`, `save_comment` and `save_project`, the plugin Linear `save_issue`, and `notion-create-comment`.
  - All 46 earlier wrong allows now ask, and deny under autopilot.
- ✅ (2) Deletes. `issue delete` and `label delete` ask (`:207`), `yes` and `_GH_YES_OPTS` are gone, and no MCP delete is on a list.
- ✅ (4) camelCase splitting and the new verbs. All 28 writes that had no vote now vote. No ask or deny from ce5bb04 became none.
- ✅ (5) gh verbs. `gh issue new` takes create's proof: it allows in the proven shape and asks with `-R`. `develop`, `pin`, `unpin`, `unlock` and `label clone` ask, and deny under autopilot.
- ✅ (6) Early return (`:194`). I tried 9 quoted or hidden gh forms; each votes on 32f5e4b exactly as on ce5bb04.
- ✅ (7), fix rounds 1-2 and the rider. The backslash-u rule (`:134`), the Linear presence checks (`:141-160`), download as a read, copilot replacing request, unstar, and the removal of `_g14_once` are all in place. Tests are at `tests/hooks/g13-g15.bats:147-245`.
- ✅ No authored vote loss. On the implementer's 290-name corpus under autopilot:
  - 176 reads give no vote. The two that changed (`get_label`, `list_label`) were false asks at ce5bb04.
  - 114 writes deny. 29 of them had no vote before.
- ⚠️ Pre-existing, not authored here: `g$'h' issue close 5`, `g${x}h ...` and `G$(:)H ...` get no vote from any guard, on ce5bb04 as well.

### Strengths

- The argument parsing holds against tricks. Each of these asks:
  - a nested or spaced key;
  - a key after the escaped forms `\"`, `\\` or `\\\"`;
  - a key or value spelled with a backslash-u escape (I built these with `printf '\134'` and checked them with `od`);
  - `"id" :` with a space before the colon.

  A duplicate key cannot defeat a presence check.
- The allow lists come from the connectors' real schemas. I re-read them: the Linear `save_issue` schema has `additionalProperties: false`, so a key outside it, such as `assigneeId`, cannot take effect.
- Reasons say what auto covers, and the github one points to gh.

### Issues

#### Critical

None.

#### Important

1. `g14-tracker.sh:26,135`: `save_project` is allowed with no argument check, but it can do what the ruling made `save_issue` ask on. I ran these under auto, and each allows:

| `save_project` input | Effect |
|---|---|
| `{"id":"P-1","setTeams":["Other"]}` | moves the project to another team |
| `{"id":"P-1","addTeams":["Secret"],"leadTeam":"Secret"}` | adds the project to another team |
| `{"id":"P-1","removeTeams":["Eng"]}` | removes the project from a team |
| `{"id":"P-1","lead":"alice"}` | assigns a person, the same class as `assignee` |

For `save_issue`, the ruling made "team with an id" and "assignee" ask. The same reasoning applies here, and the schema lists these keys.

Fix: `save_project` asks when `lead` is present, and also when `addTeams`, `setTeams`, `removeTeams` or `leadTeam` is present together with `id`. These are presence checks in the same shape as `_g14_linear_issue_args`, so they are cheap. Add tests for the four inputs above.

A lower-cost neighbour: `save_issue_label` and `create_issue_label` with no `teamId`, and a label rename by name (`"id":"Bug"`), act on a workspace-wide label that every team sees. These are label writes, which the ruled list covers, so I would leave them.

Accepted by the ruling and not counted:
- `save_issue` creating in any team (`{"team":"Other",...}`).
- `@mentions` in Linear bodies and Notion comment mention objects, which notify people.
- `notion-create-comment` on any page the integration reaches.

#### Minor

2. `g14-tracker.sh:85`: the read-first rule returns before anything else, autopilot included. So any name whose first word is a read verb gets no vote, whatever follows.
   - Under autopilot, all 20 probes of that shape got no vote. Examples: `get_or_create_issue`, `find_or_create_issue`, `getAndDeleteBranch`, `list_and_close_issues`, `read_and_reply`, and a generic `query_graphql`.
   - I found no such write in a real connector: the read corpus, the Linear and Notion lists, and the github names I know.

   Fix: skip a read-first name only when no other word is a strong write verb (create, update, delete, remove, save, send, push, write, edit, archive, close, share, publish, reply, upload, submit, move, assign). In a scratch copy, that kept all 176 corpus reads at no vote, and `get_workflow_run`, `pull_request_read`, `get_merge_request` and `download_workflow_run_artifact` stayed silent. It caught 5 of the 6 probes I re-ran. `fetch_and_merge_upstream` still gets no vote, because `merge` stays out of the strong set so that gitlab's `get_merge_request` does not start asking. Cheap and safe.

### Assessment

**Task quality:** Needs fixes. The closed lists, token match, delete rule, gh verbs and escape hardening all hold under probing, but Linear `save_project` still allows the team moves and the person assignment that the ruling made `save_issue` ask on.
