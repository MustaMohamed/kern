# shellcheck shell=bash
# G4 untrusted text: PR, issue and review text goes through a file, never inline in the command.

guard_g04() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg words w
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    case "$(gh_sub "$seg")" in
      "pr "* | "issue "* | "release "*)
        words=$(_shell_words "$seg")
        if word_has "$words" --body -b || printf '%s\n' "$words" | grep -q '^--body='; then
          vote deny G4 "pass PR, issue and review text with --body-file <file>, not inline"
        fi
        ;;
      api*)
        words=$(_shell_words "$seg")
        while IFS= read -r w; do
          case "$w" in
            body=* | -fbody=* | -Fbody=*) vote deny G4 "send gh api bodies with --input <file>, not -f body="; break ;;
          esac
        done <<EOT
$words
EOT
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}
