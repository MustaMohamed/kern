# shellcheck shell=bash
# G15 deploy and publish: workflow runs, releases, package publishes, infra applies, deploy-branch pushes.

KERN_G15_RE='^(gh (workflow run|release (create|upload|edit|delete))|(npm|pnpm|yarn( npm)?|bun) publish|cargo publish|twine upload|gem push|poetry publish|docker (push|buildx build .*--push)|(terraform|tofu) (apply|destroy|import)|pulumi (up|destroy)|cdk (deploy|destroy)|kubectl (apply|create|delete|replace|patch|rollout|scale|set|edit|annotate|label)|helm (install|upgrade|uninstall|rollback)|(serverless|sls) (deploy|remove)|vercel( .*)? (--prod|deploy)|fly (deploy|apps destroy)|firebase deploy|eb deploy|aws (ecs update-service|lambda update-function-code|cloudformation (deploy|create-stack|update-stack|delete-stack)|s3 (sync|cp|rm|mv) .*s3://))'

guard_g15() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg words parsed dir rest sub t envs
  cmd=$(ti_get command) || return 0
  envs=$(settings_get deploy.envs '')
  while IFS= read -r seg; do
    words=$(_shell_words "$seg" | awk '!s && /^[A-Za-z_][A-Za-z0-9_]*=/ { next } !s && /^(command|exec|time|nohup|sudo|npx)$/ { next } { s = 1; print }' | paste -sd ' ' -)
    if printf '%s\n' "$words" | grep -Eq -- "$KERN_G15_RE"; then
      _g15_vote "$(printf '%s' "$words" | cut -c1-60)"
      continue
    fi
    [ -n "$envs" ] || continue
    parsed=$(git_sub "$seg") || continue
    dir=${parsed%%	*}
    rest=${parsed#*	}
    sub=${rest%%	*}
    rest=${rest#*	}
    [ "$sub" = push ] || continue
    while IFS= read -r t; do
      [ -n "$t" ] && list_has "$envs" "$t" && _g15_vote "push to deploy branch $t"
    done <<EOT
$(push_targets "$dir" "$rest")
EOT
  done <<EOT
$(git_words "$cmd")
EOT
}

_g15_vote() {
  vote ask G15 "deploy or publish: $1"
  [ "$AUTOPILOT" = 1 ] && vote deny G15 "deploy or publish under autopilot: $1"
  return 0
}
