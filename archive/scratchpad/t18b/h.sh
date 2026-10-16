#!/usr/bin/env bash
# Human-in-the-loop reproduction loop. Copy this file, edit the steps between the markers, and run it.
# The agent runs the script; the user follows the prompts in their terminal.
#   step "<instruction>"        show an instruction, wait for Enter
#   capture VAR "<question>"    show a question, read the answer into VAR
# At the end, captured values print as KEY=VALUE for the agent to parse. Capture observations only;
# leave signing in to the user as a step. Run it in the user's terminal (a Bash call here has no stdin),
# for example `! bash <path>`, and have them paste the KEY=VALUE lines back. The script exits 1 when its input closes before the last step.
# Adapted from mattpocock/skills diagnosing-bugs/scripts/hitl-loop.template.sh (MIT).
# shellcheck disable=SC2154  # captured variables are set through printf -v
set -euo pipefail

step() {
  local _
  printf '\n>>> %s\n' "$1"
  read -r -p "    [Enter when done] " _ || { echo "hitl-loop: input closed before the step finished" >&2; exit 1; }
}

capture() {
  local var="$1" question="$2" answer
  printf '\n>>> %s\n' "$question"
  read -r -p "    > " answer || { echo "hitl-loop: input closed before the question was answered" >&2; exit 1; }
  answer=${answer%$'\r'}
  printf -v "$var" '%s' "$answer"
}

# --- edit below ---------------------------------------------------------

step "Open the app and sign in."

capture ERRORED "Do the action that fails. Did it show an error? (y/n)"

capture ERROR_MSG "Paste the error message (or 'none'):"

# --- edit above ---------------------------------------------------------

printf '\n--- Captured ---\n'
printf 'ERRORED=%s\n' "$ERRORED"
printf 'ERROR_MSG=%s\n' "$ERROR_MSG"
