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
# terraform apply`, `man kubectl apply`), ask. Quoted text stays one word. After a runner (npx,
# bunx, uvx, pnpx; npm exec or x, pnpm and yarn dlx or exec, bun x, uv run or uv tool run,
# python -m), each later word is also split at blanks (`npm exec -c 'vercel deploy'`).
# Out of scope (accepted limits): package scripts (npm run deploy, make deploy), a bare `vercel`
# with an option value or a path (`vercel --scope team`), and names built at run time.

# _G15_AWK: the judge, run on git_words records after _GW_AWK. Prints `D<TAB>words` for a deploy or
# publish, `P<TAB>record` for a git command with a push word, and `.` at the end.
# shellcheck disable=SC2016 # awk text
_G15_AWK='
  function g15_tool(names, paths,   a, k, n) { n = split(names, a, ","); for (k = 1; k <= n; k++) G15T[a[k]] = paths }
  # g15_name(w): the tool w runs: its basename in lower case, less a :tag (hashicorp/terraform:1.9)
  # and an @version (vercel@latest); python3.12 and the like read as python.
  function g15_name(w) {
    sub(/.*\//, "", w); w = tolower(w)
    if (w ~ /^python[0-9.]*$/) return "python"
    if (w ~ /^[^:]+:/) sub(/:.*/, "", w)
    if (w ~ /^[^@]+@/) sub(/@.*/, "", w)
    return w
  }
  # g15_has(p, path): true when the words of path appear in L after position p, in order, each a
  # whole word; a path word ending in * matches any word it starts. The path ~ is a bare run: the
  # word at p runs (the head, or after a runner) and every later word is an option other than help
  # or version.
  function g15_has(p, path,   a, n, k, j, e, x) {
    if (path == "~") {
      if (p > 1 && !(r && p > r)) return 0
      for (j = p + 1; j <= m; j++) if (L[j] !~ /^-/ || L[j] ~ /^(-h|--help|-v|--version)$/) return 0
      return 1
    }
    n = split(path, a, " "); j = p
    for (k = 1; k <= n; k++) {
      e = a[k]; x = (e ~ /\*$/)
      if (x) e = substr(e, 1, length(e) - 1)
      for (j++; j <= m; j++) if (x ? substr(L[j], 1, length(e)) == e : L[j] == e) break
      if (j > m) return 0
    }
    return 1
  }
  BEGIN {
    g15_tool("gh", "workflow run|release create|release new|release upload|release edit|release delete|release delete-asset|run rerun")
    g15_tool("npm,pnpm,yarn,bun,cargo,poetry,uv,lerna,changeset", "publish")
    g15_tool("twine", "upload")
    g15_tool("gem", "push")
    g15_tool("docker", "push|--push|stack deploy|stack up")
    g15_tool("docker-compose", "push")
    g15_tool("terraform,tofu", "apply|destroy|import")
    g15_tool("pulumi", "up|destroy")
    g15_tool("cdk,aws-cdk", "deploy|destroy")
    g15_tool("kubectl", "apply|create|delete|replace|patch|rollout|scale|set|edit|annotate|label")
    g15_tool("helm", "install|upgrade|uninstall|rollback|delete|del|un")
    g15_tool("serverless,sls", "deploy|remove")
    g15_tool("vercel", "deploy|--prod|~")
    g15_tool("fly,flyctl", "deploy|apps destroy")
    g15_tool("firebase,firebase-tools", "deploy")
    g15_tool("eb", "deploy")
    g15_tool("gcloud", "run deploy|app deploy|functions deploy")
    g15_tool("wrangler", "deploy|publish")
    g15_tool("netlify,netlify-cli", "deploy")
    g15_tool("aws", "ecs update-service|lambda update-function-code|cloudformation deploy|cloudformation create-stack|cloudformation update-stack|cloudformation delete-stack|s3 sync s3://*|s3 cp s3://*|s3 rm s3://*|s3 mv s3://*|s3 rb s3://*")
    # Runners: a head that runs the command in its later words, alone (" ") or after a listed word.
    G15R["npx"] = G15R["bunx"] = G15R["uvx"] = G15R["pnpx"] = " "
    G15R["npm"] = " exec x "; G15R["pnpm"] = " dlx exec "; G15R["yarn"] = " dlx exec "; G15R["bun"] = " x "
    G15R["uv"] = " run "; G15R["python"] = " -m "
  }
  {
    sw($0); cw_reset()
    for (k = 1; k <= sw_n; k++) cw(sw_w[k])
    if (!cw_n) next
    # L[1..m]: the words; r: where a runner ends, after which words are split at blanks.
    h = g15_name(cw_w[1]); m = 1; L[1] = cw_w[1]
    r = (h in G15R && G15R[h] == " ")
    for (k = 2; k <= cw_n; k++) {
      if (r) { n = split(cw_w[k], a, /[ \t\037]+/); for (i = 1; i <= n; i++) if (a[i] != "") L[++m] = a[i]; continue }
      L[++m] = cw_w[k]
      if (h in G15R && index(G15R[h], " " cw_w[k] " ")) r = m
    }
    for (p = 1; p <= m; p++) {
      t = g15_name(L[p])
      if (!(t in G15T)) continue
      n = split(G15T[t], v, "|")
      for (i = 1; i <= n; i++) if (g15_has(p, v[i])) break
      if (i > n) continue
      out = L[1]
      for (k = 2; k <= m; k++) out = out " " L[k]
      gsub(/\037/, " ", out)
      print "D\t" substr(out, 1, 60)
      next
    }
    if (cw_w[1] == "git" || cw_w[1] ~ /\/git$/) for (k = 2; k <= cw_n; k++) if (cw_w[k] == "push") { print "P\t" $0; next }
  }
  END { print "." }
'

guard_g15() {
  [ "$TOOL" = Bash ] || return 0
  local cmd line seen=0 got=0 envs="" parsed dir rest sub t
  cmd=$(ti_get command) || return 0
  _g15_named "$cmd" || return 0
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
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
$(git_words "$cmd" | LC_ALL=C awk -v sq="'" "$_GW_AWK$_G15_AWK")
EOT
  [ "$seen" = 1 ] || _g15_vote "kern could not read the command"
}

# _g15_named CMD: exit 0 when CMD, with quotes, backslashes and newlines removed, holds a tool name
# from _G15_AWK's table or push, in any case. It runs before any parse or settings_get, and is a
# superset of what the judge can match: a name the shell joins from quotes or a continued line
# still passes.
_g15_named() {
  local flat=${1//[\"\'\\]/}
  flat=${flat//$'\n'/}
  case "$flat" in
    *[Gg][Hh]* | *[Nn][Pp][Mm]* | *[Yy][Aa][Rr][Nn]* | *[Bb][Uu][Nn]* | *[Cc][Aa][Rr][Gg][Oo]* | \
      *[Pp][Oo][Ee][Tt][Rr][Yy]* | *[Uu][Vv]* | *[Ll][Ee][Rr][Nn][Aa]* | *[Cc][Hh][Aa][Nn][Gg][Ee][Ss][Ee][Tt]* | \
      *[Tt][Ww][Ii][Nn][Ee]* | *[Gg][Ee][Mm]* | *[Dd][Oo][Cc][Kk][Ee][Rr]* | *[Tt][Ee][Rr][Rr][Aa][Ff][Oo][Rr][Mm]* | \
      *[Tt][Oo][Ff][Uu]* | *[Pp][Uu][Ll][Uu][Mm][Ii]* | *[Cc][Dd][Kk]* | *[Kk][Uu][Bb][Ee][Cc][Tt][Ll]* | *[Hh][Ee][Ll][Mm]* | \
      *[Ss][Ee][Rr][Vv][Ee][Rr][Ll][Ee][Ss][Ss]* | *[Ss][Ll][Ss]* | *[Vv][Ee][Rr][Cc][Ee][Ll]* | *[Ff][Ll][Yy]* | \
      *[Ff][Ii][Rr][Ee][Bb][Aa][Ss][Ee]* | *[Ee][Bb]* | *[Gg][Cc][Ll][Oo][Uu][Dd]* | *[Ww][Rr][Aa][Nn][Gg][Ll][Ee][Rr]* | \
      *[Nn][Ee][Tt][Ll][Ii][Ff][Yy]* | *[Aa][Ww][Ss]* | *[Pp][Uu][Ss][Hh]*) return 0 ;;
  esac
  return 1
}

_g15_vote() {
  vote ask G15 "deploy or publish: $1"
  [ "$AUTOPILOT" = 1 ] && vote deny G15 "deploy or publish under autopilot: $1"
  return 0
}
