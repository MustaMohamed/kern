### Spec Compliance

- ✅ Ruling (1), heads from `_cmd_words`: `g15-deploy.sh:76-87`; test `g13-g15.bats:465`.
- ✅ Ruling (2), verb anywhere, no option tables: `:35-49`, `:88-99`; `:474` pins `terraform plan -out apply` as an ask.
- ✅ Ruling (3), runners: `:72-87`; test `:485`.
- ✅ Ruling (4), added tools: `:50-70`; `:539` checks every entry in both cases.
- ✅ Ruling (5), the prefilter runs before `settings_get` (`:109`); `deploy.envs` is read only for a push (`:119`). Cost: Important 1.
- ✅ Riders: any word names a tool; bare `vercel` (`:35-41`); `:tag` (`:27`); `docker-compose push` (`:56`).
- ⚠️ Ruling (4) asks for a help check per tool; the report checked only installed tools. The docs confirm `helm del`/`un`, `gh release new`, `docker stack up` and `wrangler publish`. The diff cannot show the rest.

### Strengths

- Every ask became a deny under autopilot in my probes. No path votes allow.
- The prefilter covers the judge. Across 244 probes, the judge never voted on a command the prefilter rejected.
- Compound forms ask: subshells, loops, `$( )`, pipes, `coproc`, `env -i`, `bash <<EOF`, backslash-newline. Heredoc commit and PR bodies get no vote.
- Small commands are faster. All guards, C locale, median of 25: `ls` 153 → 140 ms, `npm test` 153 → 145 ms.
- An error injected into `_G15_AWK` asks "kern could not read the command".
- `g13-g15.bats` 57/57 on my `git archive 6f739e3` tree.

### Issues

#### Critical

None.

#### Important

1. `g15-deploy.sh:152`: the prefilter's strip is cubic under bash 3.2, so long commands time out. Each doubling of the command multiplies the cost of `${1//[\"\'\\]/}` by 7 to 8. `_g15_named` alone in en_US.UTF-8 takes 129 ms at 1.3 KB, 6.0 s at 5.1 KB and 44 s at 10.1 KB. Below, `gh pr create --body "$(cat <<'EOF' …)"`, all guards, en_US.UTF-8:

   | Size | 94d011e | 6f739e3 |
   |---|---|---|
   | 2.5 KB | 1.2 s | 2.1 s |
   | 4.9 KB | 6.3 s | 12.4 s |
   | 6.5 KB | 13.1 s | 26.5 s |

   At 6.5 KB the hook overruns the 20 s timeout in `hooks/hooks.json:7` (`onFailure: block`). The PR cannot be opened, or, if the host ignores the key, the call runs unguarded. The `env -i` harness runs in the C locale (2.3 s at 5.3 KB), so the implementer's timings missed it. The 94d011e half is G13's identical strip (`g13-protected.sh:22`, outside this unit). Fix: one linear pass, `printf '%s' "$1" | LC_ALL=C tr -d '"\047\\\n' | LC_ALL=C grep -iqE 'gh|npm|…'`, and the same in G13 (`:22`, `:33`). Test: a 10 KB heredoc body finishes in under a second.

2. `g15-deploy.sh:82-84`: a deploy inside one quoted word gets no vote. Words split at blanks only after a runner at the head, so a remote or shell command stays one word. 9 of 9 probes got no vote, among them:
   - `ssh prod 'kubectl apply -f x.yml'`, `ssh deploy@web1 "cd /srv/app && npm publish"`
   - `docker exec api sh -c 'npm publish'`, `caffeinate -i sh -c 'terraform apply'`
   - `su deploy -c 'npm publish'`, `watch 'kubectl rollout restart deploy/api'`

   Rider (a)'s test (`:519`) uses the unquoted `ssh build-host kubectl apply`, but Claude quotes the remote command. Fix: start splitting (set `r`) at ssh's remote command, after a `-c` cluster that follows any sh, bash, zsh or dash word, after `su -c` and `script -c`, and after `watch`. Cost: `ssh h 'echo terraform apply'` asks, the accepted `echo` class.

3. `g15-deploy.sh:51-70`: the table misses whole ecosystems. About 80 of 95 deploy and publish probes outside the accepted limits got no vote, so autopilot runs them unattended. Most likely first:
   - Kubernetes and containers: `helmfile apply|sync`, `argocd app sync`, `podman push`, `helm push`, `skaffold run`, `oc apply`, `kubectl run|expose|drain`.
   - Infrastructure: `terragrunt apply`, `terragrunt run-all apply`, `sam deploy`, `sst deploy`.
   - Registries: `mvn deploy`, `./gradlew publish`, `dotnet nuget push`, `npm unpublish`, `npm dist-tag add`, `npx semantic-release`, `vsce publish`.
   - Hosting: `eas update --branch production`, `eas submit`, `vercel promote|rollback|redeploy`, `firebase hosting:channel:deploy`, `supabase functions deploy`, `railway up`, `kamal deploy`.
   - Clouds: every `az` and `azd` command; `gsutil rsync … gs://`; `gcloud builds submit`; `aws s3api put-object`, `aws lambda publish-version`.
   - GitLab: `glab release create`, `glab ci run`.

   Fix: the controller picks the rows, one table line each. Short names (`az`, `oc`, `eas`, `sam`) match most commands as substrings, so fix Important 1 first.

#### Minor

4. False asks. Five of 127 ordinary probes are new since 94d011e: `helm diff upgrade api ./chart`, `npm test -- -t publish`, `kubectl describe clusterrole edit`, `kubectl config set current-context prod`, `docker run --rm alpine echo push`. Older, plan-mandated false asks hit common reads:
   - `kubectl rollout status|history`
   - `--dry-run` forms: `kubectl create … --dry-run=client -o yaml`, `helm install|upgrade --dry-run`, `npm publish --dry-run`
   - `aws s3 cp|sync s3://… ./local` downloads

   Fix:
   - kubectl paths `rollout restart|undo|pause|resume`.
   - A `--dry-run` or `--dry-run=client|server` word ends the vote.
   - For s3 copies, the `s3://` word must be the last positional.
   - A helm `diff` before the verb means no vote.

5. `g15-deploy.sh:142-144`: fail closed covers only the judge, and no test pins it. I injected a runtime error into `_split_words`: no records came out, the judge still printed `.`, and `npm publish; boom` got no vote. 400 fuzzed inputs raised no awk error, so I found no real trigger. No test references "could not read the command". Fix: run the substitution under `set -o pipefail` and drop the `.` when `git_words` fails. Add a test that breaks the judge and expects an ask.

### Assessment

**Task quality:** Needs fixes. The judge is sound and the prefilter covers it, but the strip pushes a 6.5 KB PR body past the hook timeout, quoted remote commands hide deploys, and the table misses whole ecosystems.
