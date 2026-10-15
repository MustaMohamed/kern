# shellcheck shell=bash
# G15 deploy and publish: workflow runs, releases, package publishes, infra applies, deploy
# commands and deploy-branch pushes ask, and are denied under autopilot. No policy key loosens it,
# and it never votes allow.
# The words of each simple command come from _cmd_words (wrappers, assignments, any path, any
# case). Any word may name a tool in _G15_AWK's table (basename, lower case, no :tag or @version),
# so an unknown wrapper, xargs, find -exec or `docker run <image>/terraform:<tag>` cannot hide it;
# the words of a verb path must then appear after it in order, each a whole word, so global options
# before the verb cannot hide it either, and no option table is needed. The costs: an option value
# spelled as a verb (`terraform plan -out apply`), and a tool and its verb as plain words (`echo
# terraform apply`, `man kubectl apply`), ask. A tool's words end at `--`; a --dry-run among them,
# or one of its read verbs before the deploy verb, ends its vote.
# Quoted text stays one word, except after a runner (npx, bunx, uvx, pnpx; npm exec or x, pnpm and
# yarn dlx or exec, bun x, uv run or uv tool run, python -m), ssh, watch, or the -c (in a cluster of
# any case, after - or +, attached too) or --command of sh, bash, zsh, dash, su or script: there each
# later word is split at blanks and its quotes dropped, since it may be a command line
# (`ssh prod 'kubectl apply -f x.yml'`).
# Out of scope (accepted limits): package scripts (npm run deploy, make deploy), a bare `vercel`
# with an option value or a path (`vercel --scope team`), and names built at run time.

# _G15_AWK: the judge, run on git_words records after _GW_AWK. Prints `D<TAB>words` for a deploy or
# publish, `P<TAB>record` for a git command with a push word, and `.` at the end.
# shellcheck disable=SC2016 # awk text
_G15_AWK='
  function g15_tool(names, paths,   a, k, n) { n = split(names, a, ","); for (k = 1; k <= n; k++) G15T[a[k]] = paths }
  # g15_reads(names, verbs): the read verbs of a tool; one before the deploy verb ends the vote.
  function g15_reads(names, verbs,   a, b, k, i, n, nb) {
    n = split(names, a, ","); nb = split(verbs, b, " ")
    for (k = 1; k <= n; k++) for (i = 1; i <= nb; i++) G15RD[a[k], b[i]] = 1
  }
  # g15_name(w): the tool w runs: its basename in lower case, less a :tag (hashicorp/terraform:1.9)
  # and an @version (vercel@latest); python3.12 and the like read as python.
  function g15_name(w,   P) {
    w = tolower(P[split(w, P, "/")])
    if (w ~ /^python[0-9.]*$/) return "python"
    if (w ~ /^[^:]+:/) sub(/:.*/, "", w)
    if (w ~ /^[^@]+@/) sub(/@.*/, "", w)
    return w
  }
  # g15_runs(p): true when the word at p runs: the head, or after r.
  function g15_runs(p) { return p == 1 || (r && p > r) }
  # g15_has(t, p, e, path): true when the words of path appear in L between p and e, in order, each
  # a whole word, with no read verb of t before the first (unless that first word is an option).
  # A path word ending in * matches any word it starts; >X matches when a positional word after the
  # verb, other than the first (the source), starts with X. The path . is a run of the tool at p;
  # ~ is a bare run, every later word an option other than help or version.
  function g15_has(t, p, e, path,   a, n, k, j, w, x, f) {
    if (path == ".") return g15_runs(p)
    if (path == "~") {
      if (!g15_runs(p)) return 0
      for (j = p + 1; j < e; j++) if (L[j] !~ /^-/ || L[j] ~ /^(-h|--help|-v|--version)$/) return 0
      return 1
    }
    n = split(path, a, " "); j = p
    for (k = 1; k <= n; k++) {
      w = a[k]
      if (w ~ /^>/) {
        w = substr(w, 2); f = 0
        for (j++; j < e; j++) if (L[j] !~ /^-./ && f++ && substr(L[j], 1, length(w)) == w) break
        if (j >= e) return 0
        continue
      }
      x = (w ~ /\*$/)
      if (x) w = substr(w, 1, length(w) - 1)
      for (j++; j < e; j++) {
        if (x ? substr(L[j], 1, length(w)) == w : L[j] == w) break
        if (k == 1 && w !~ /^-/ && ((t, L[j]) in G15RD)) return 0
      }
      if (j >= e) return 0
    }
    return 1
  }
  BEGIN {
    g15_tool("gh", "workflow run|release create|release new|release upload|release edit|release delete|release delete-asset|run rerun")
    g15_tool("npm", "publish|unpublish|deprecate|dist-tag add")
    g15_tool("pnpm,yarn,bun,poetry,uv,changeset,deno,jsr,vsce,ovsx,sbt", "publish")
    g15_tool("cargo", "publish|release|yank")
    g15_tool("lerna", "publish|version")
    g15_tool("twine", "upload")
    g15_tool("gem", "push")
    g15_tool("docker", "push|--push|stack deploy|stack up|imagetools create")
    g15_tool("docker-compose,podman", "push")
    g15_tool("terraform,tofu,terragrunt", "apply|destroy|import")
    g15_tool("pulumi", "up|destroy")
    g15_tool("cdk,aws-cdk", "deploy|destroy")
    g15_tool("kubectl,oc", "apply|create|delete|replace|patch|rollout restart|rollout undo|rollout pause|rollout resume|scale|set|edit|annotate|label|run|expose|drain|cordon|taint|cp")
    g15_tool("helm", "install|upgrade|uninstall|rollback|delete|del|un|push")
    g15_tool("helmfile", "apply|sync|destroy")
    g15_tool("argocd", "app sync|app create|app delete|app rollback")
    g15_tool("skaffold", "run|deploy|delete")
    g15_tool("serverless,sls", "deploy|remove")
    g15_tool("sam", "deploy|delete")
    g15_tool("sst", "deploy|remove")
    g15_tool("vercel", "deploy|--prod|promote|rollback|redeploy|remove|alias set|~")
    g15_tool("fly,flyctl", "deploy|apps destroy|secrets set|secrets unset|scale")
    g15_tool("firebase,firebase-tools", "deploy|hosting:channel:deploy|functions:delete")
    g15_tool("eb", "deploy")
    g15_tool("gcloud", "run deploy|app deploy|functions deploy|builds submit|deploy releases create|run services update|run services update-traffic|run services delete|storage cp >gs://|storage mv gs://*|storage rm gs://*")
    g15_tool("gsutil", "rsync >gs://|cp >gs://|mv gs://*|rm gs://*")
    g15_tool("wrangler", "deploy|publish")
    g15_tool("netlify,netlify-cli", "deploy")
    g15_tool("mvn,mvnw", "deploy")
    g15_tool("gradle,gradlew", "publish")
    g15_tool("dotnet", "nuget push")
    g15_tool("semantic-release,release-it,gh-pages,surge", ".")
    g15_tool("eas", "update|submit|build --auto-submit*|build -s")
    g15_tool("supabase", "functions deploy|db push")
    g15_tool("railway", "up|deploy")
    g15_tool("kamal", "deploy|rollback")
    g15_tool("az", "create|delete|update|deploy|upload|swap|restart|start|stop|publish|push")
    g15_tool("azd", "up|deploy|provision|down")
    g15_tool("glab", "release create|release upload|release delete|ci run")
    g15_tool("flux", "reconcile")
    g15_tool("func", "publish")
    g15_tool("prisma", "migrate deploy")
    g15_tool("convex", "deploy")
    g15_tool("nx", "release publish")
    g15_tool("heroku", "container:release|releases:rollback")
    g15_tool("mix", "hex.publish")
    g15_tool("pod", "trunk push")
    g15_tool("dart,flutter", "pub publish")
    g15_tool("skopeo", "copy")
    g15_tool("cdktf", "deploy|destroy")
    g15_tool("aws", "ecs update-service|lambda update-function-code|lambda publish-version|lambda create-function|lambda delete-function|lambda update-function-configuration|cloudformation deploy|cloudformation create-stack|cloudformation update-stack|cloudformation delete-stack|s3 sync >s3://|s3 cp >s3://|s3 mv s3://*|s3 rm s3://*|s3 rb s3://*|s3api put-object|s3api delete-object|s3api delete-bucket|s3api put-bucket-policy|cloudfront create-invalidation|deploy create-deployment|elasticbeanstalk update-environment")
    g15_reads("kubectl,oc", "get describe logs explain top config auth diff wait version api-resources cluster-info events")
    g15_reads("helm", "diff template lint show status history get list search repo")
    g15_reads("docker", "run exec build inspect logs ps images")
    # Where a command line starts: after the word itself (" "), after a listed word that follows it,
    # or after a -c cluster or --command that follows it ("-c"), whose attached value is one too.
    G15R["npx"] = G15R["bunx"] = G15R["uvx"] = G15R["pnpx"] = G15R["ssh"] = G15R["watch"] = " "
    G15R["npm"] = " exec x "; G15R["pnpm"] = " dlx exec "; G15R["yarn"] = " dlx exec "; G15R["bun"] = " x "
    G15R["uv"] = " run "; G15R["python"] = " -m "
    G15R["sh"] = G15R["bash"] = G15R["zsh"] = G15R["dash"] = G15R["su"] = G15R["script"] = "-c"
    qre = "[\"" sq "]"
  }
  {
    sw($0); cw_reset()
    for (k = 1; k <= sw_n; k++) cw(sw_w[k])
    if (!cw_n) next
    # L[1..m]: the words. r: where a command line starts (a runner, ssh, watch, a -c); each word
    # after it is split at blanks, its quotes dropped. host: the last word that may start one later.
    m = 0; r = 0; host = ""
    for (k = 1; k <= cw_n; k++) {
      if (r) {
        n = split(cw_w[k], a, /[ \t\037]+/)
        for (i = 1; i <= n; i++) { gsub(qre, "", a[i]); if (a[i] != "") L[++m] = a[i] }
        continue
      }
      L[++m] = cw_w[k]
      if (host != "" && G15R[host] == "-c" && (cw_w[k] ~ /^[-+][A-Za-z]*c/ || cw_w[k] ~ /^--command(=|$)/)) {
        r = m
        x = ""
        if (cw_w[k] ~ /^--command=/) x = substr(cw_w[k], 11)
        else if (cw_w[k] ~ /^[-+][A-Za-z]*c/) x = substr(cw_w[k], index(cw_w[k], "c") + 1)
        n = split(x, a, /[ \t\037]+/)
        for (i = 1; i <= n; i++) { gsub(qre, "", a[i]); if (a[i] != "") L[++m] = a[i] }
        continue
      }
      if (host != "" && G15R[host] != "-c" && index(G15R[host], " " cw_w[k] " ")) { r = m; continue }
      h = g15_name(cw_w[k])
      if (h in G15R) { if (G15R[h] == " ") r = m; else host = h }
    }
    for (p = 1; p <= m; p++) {
      t = g15_name(L[p])
      if (!(t in G15T)) continue
      # e: the end of the tool words, at the first -- after it. A --dry-run among them ends the vote.
      for (e = p + 1; e <= m && L[e] != "--"; e++) if (L[e] ~ /^--dry-run(=client|=server)?$/) break
      if (e <= m && L[e] != "--") continue
      n = split(G15T[t], v, "|")
      for (i = 1; i <= n; i++) if (g15_has(t, p, e, v[i])) break
      if (i > n) continue
      out = L[1]
      for (k = 2; k <= m; k++) out = out " " L[k]
      gsub(/\037/, " ", out)
      print "D\t" substr(out, 1, 60)
      next
    }
    b = tolower(cw_w[1])
    if (b == "git" || b ~ /\/git$/) for (k = 2; k <= cw_n; k++) if (cw_w[k] == "push") { print "P\t" $0; next }
  }
  END { print "." }
'

guard_g15() {
  [ "$TOOL" = Bash ] || return 0
  local cmd out line seen=0 got=0 envs="" parsed dir rest sub t
  cmd=$(ti_get command) || return 0
  _g15_named "$cmd ${KERN_ALIAS_TEXT-}" || return 0
  # A failed parse or judge leaves no `.`, so G15 asks.
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
  out=$(set -o pipefail; git_words "$cmd" | LC_ALL=C awk -v sq="'" "$_GW_AWK$_G15_AWK") || out=""
  while IFS= read -r line; do
    case "$line" in
      .) seen=1; continue ;;
      D*) _g15_vote "${line#D	}"; continue ;;
      P*) ;;
      *) continue ;;
    esac
    # deploy.envs is read only for a git push.
    [ "$got" = 1 ] || { envs=$(settings_get deploy.envs ''); got=1; }
    [ -n "$envs" ] || continue
    parsed=$(git_sub "${line#P	}") || continue
    dir=${parsed%%	*}
    rest=${parsed#*	}
    sub=${rest%%	*}
    rest=${rest#*	}
    [ "$sub" = push ] || continue
    # On a detached HEAD push_targets prints nothing for a push with no refspec, and an empty line
    # for HEAD or @; it prints * for --all, --mirror, --branches or a pattern. Each target is
    # unknown, so it may be a deploy branch.
    while IFS= read -r t; do
      if [ -z "$t" ]; then
        _g15_vote "push from a detached HEAD: the target branch is unknown"
      elif [ "$t" = '*' ]; then
        _g15_vote "push of every branch or a pattern may reach a deploy branch"
      elif list_has "$envs" "$t"; then
        _g15_vote "push to deploy branch $t"
      fi
    done <<EOT
$(push_targets "$dir" "$rest")
EOT
  done <<EOT
$out
EOT
  [ "$seen" = 1 ] || _g15_vote "kern could not read the command"
}

# _g15_named CMD: exit 0 when CMD, with quotes, backslashes and newlines removed, holds a tool name
# from _G15_AWK's table or push, in any case. It runs before any parse or settings_get, and is a
# superset of what the judge can match: a name the shell joins from quotes or a continued line
# still passes. The strip is one linear tr pass: bash 3.2's ${x//[...]/} is cubic on long text in
# a UTF-8 locale.
_g15_named() {
  local flat=$1
  case "$1" in *[\"\'\\]* | *$'\n'*) flat=$(printf '%s' "$1" | LC_ALL=C tr -d '"\047\\\n') ;; esac
  case "$flat" in
    *[Gg][Hh]* | *[Nn][Pp][Mm]* | *[Yy][Aa][Rr][Nn]* | *[Bb][Uu][Nn]* | *[Cc][Aa][Rr][Gg][Oo]* | \
      *[Pp][Oo][Ee][Tt][Rr][Yy]* | *[Uu][Vv]* | *[Ll][Ee][Rr][Nn][Aa]* | \
      *[Cc][Hh][Aa][Nn][Gg][Ee][Ss][Ee][Tt]* | *[Tt][Ww][Ii][Nn][Ee]* | *[Gg][Ee][Mm]* | \
      *[Dd][Oo][Cc][Kk][Ee][Rr]* | *[Pp][Oo][Dd][Mm][Aa][Nn]* | \
      *[Tt][Ee][Rr][Rr][Aa][Ff][Oo][Rr][Mm]* | *[Tt][Oo][Ff][Uu]* | \
      *[Tt][Ee][Rr][Rr][Aa][Gg][Rr][Uu][Nn][Tt]* | *[Pp][Uu][Ll][Uu][Mm][Ii]* | *[Cc][Dd][Kk]* | \
      *[Kk][Uu][Bb][Ee][Cc][Tt][Ll]* | *[Oo][Cc]* | *[Hh][Ee][Ll][Mm]* | \
      *[Aa][Rr][Gg][Oo][Cc][Dd]* | *[Ss][Kk][Aa][Ff][Ff][Oo][Ll][Dd]* | \
      *[Ss][Ee][Rr][Vv][Ee][Rr][Ll][Ee][Ss][Ss]* | *[Ss][Ll][Ss]* | *[Ss][Aa][Mm]* | \
      *[Ss][Ss][Tt]* | *[Vv][Ee][Rr][Cc][Ee][Ll]* | *[Ff][Ll][Yy]* | \
      *[Ff][Ii][Rr][Ee][Bb][Aa][Ss][Ee]* | *[Ee][Bb]* | *[Gg][Cc][Ll][Oo][Uu][Dd]* | \
      *[Gg][Ss][Uu][Tt][Ii][Ll]* | *[Ww][Rr][Aa][Nn][Gg][Ll][Ee][Rr]* | \
      *[Nn][Ee][Tt][Ll][Ii][Ff][Yy]* | *[Mm][Vv][Nn]* | *[Gg][Rr][Aa][Dd][Ll][Ee]* | \
      *[Dd][Oo][Tt][Nn][Ee][Tt]* | *[Ss][Ee][Mm][Aa][Nn][Tt][Ii][Cc]* | *[Vv][Ss][Cc][Ee]* | \
      *[Oo][Vv][Ss][Xx]* | *[Ee][Aa][Ss]* | *[Ss][Uu][Pp][Aa][Bb][Aa][Ss][Ee]* | \
      *[Rr][Aa][Ii][Ll][Ww][Aa][Yy]* | *[Kk][Aa][Mm][Aa][Ll]* | *[Aa][Zz]* | *[Gg][Ll][Aa][Bb]* | \
      *[Aa][Ww][Ss]* | *[Ff][Ll][Uu][Xx]* | *[Ff][Uu][Nn][Cc]* | *[Pp][Rr][Ii][Ss][Mm][Aa]* | \
      *[Cc][Oo][Nn][Vv][Ee][Xx]* | *[Rr][Ee][Ll][Ee][Aa][Ss][Ee]-[Ii][Tt]* | \
      *[Ss][Uu][Rr][Gg][Ee]* | *[Nn][Xx]* | *[Dd][Ee][Nn][Oo]* | *[Jj][Ss][Rr]* | \
      *[Hh][Ee][Rr][Oo][Kk][Uu]* | *[Mm][Ii][Xx]* | *[Pp][Oo][Dd]* | *[Dd][Aa][Rr][Tt]* | \
      *[Ff][Ll][Uu][Tt][Tt][Ee][Rr]* | *[Ss][Bb][Tt]* | *[Ss][Kk][Oo][Pp][Ee][Oo]* | \
      *[Pp][Uu][Ss][Hh]*) return 0 ;;
  esac
  return 1
}

_g15_vote() {
  vote ask G15 "deploy or publish: $1"
  [ "$AUTOPILOT" = 1 ] && vote deny G15 "deploy or publish under autopilot: $1"
  return 0
}
