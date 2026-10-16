#!/bin/bash
# run.sh CMD: runs CMD the way the Claude Code Bash tool does, with the test snapshot.
snap="$(dirname "$0")/snap.sh"
q=$(printf '%s' "$1" | sed "s/'/'\\\\''/g")
/bin/zsh -c "source $snap 2>/dev/null || true && : && setopt NO_EXTENDED_GLOB NO_BARE_GLOB_QUAL 2>/dev/null || true && eval '$q' < /dev/null" 2>&1
