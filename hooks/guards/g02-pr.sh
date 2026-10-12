# shellcheck shell=bash
# G2 PR create: drafts only, no duplicate PR for a head, `gh pr ready` stays human under autopilot.

guard_g02() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    case "$(gh_sub "$seg")" in
      "pr create") _g02_create "$seg" ;;
      "pr ready")
        word_has "$(_shell_words "$seg")" --undo && continue
        vote ask G2 "gh pr ready marks a PR ready for review"
        [ "$AUTOPILOT" = 1 ] && vote deny G2 "gh pr ready under autopilot: drafts only"
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

# _g02_states HEAD: states of PRs whose head is HEAD, one per line. Exit 2 when gh cannot answer.
_g02_states() {
  command -v gh >/dev/null 2>&1 || return 2
  (cd "$CWD" 2>/dev/null && with_timeout 10 gh pr list --head "$1" --state all --json state --jq '.[].state') 2>/dev/null || return 2
}

_g02_create() {
  local words head states policy
  words=$(_shell_words "$1")
  if ! word_has "$words" --draft -d; then
    vote deny G2 "open PRs as drafts: add --draft"
    return 0
  fi
  head=$(word_value "$words" --head -H) || head=$(current_branch "$CWD")
  if ! states=$(_g02_states "$head"); then
    vote ask G2 "could not check for an existing PR on $head (gh unavailable)"
    return 0
  fi
  case "$states" in
    *OPEN*) vote deny G2 "a PR is already open for $head; report it instead of opening another"; return 0 ;;
    *MERGED* | *CLOSED*) vote ask G2 "a merged or closed PR already exists for $head"; return 0 ;;
  esac
  if [ "$AUTOPILOT" = 1 ]; then
    vote allow G2 "autopilot: draft PR for $head after dedup"
    return 0
  fi
  policy=$(policy_for pr)
  case "$policy" in
    auto) vote allow G2 "pr.policy auto: draft PR for $head" ;;
    deny) vote deny G2 "pr.policy deny" ;;
    *) vote ask G2 "open a draft PR for $head" ;;
  esac
}
