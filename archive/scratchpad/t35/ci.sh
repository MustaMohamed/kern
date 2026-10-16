#!/bin/bash
# ci.sh SHA AWK: git archive SHA into a kern-ci:task17 container and run the changed bats files as uid 1000.
# AWK mawk uses the image's awk; gawk installs gawk first and shims awk to it.
set -e
T=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35
sha=$1; aw=$2
git -C /Users/musta/Code/projects/kern archive "$sha" > "$T/ci-$sha.tar"
files=${FILES:-"tests/hooks/gitctx.bats tests/hooks/g00-unproven.bats tests/hooks/g01-git.bats tests/hooks/g05-g06-commit.bats tests/hooks/g16-state.bats tests/hooks/g20-probes.bats tests/hooks/pre-tool-use.bats"}
docker run --rm -i -v "$T/ci-$sha.tar:/k.tar:ro" kern-ci:task17 bash -s "$aw" "$files" <<'IN'
aw=$1; files=$2
if [ "$aw" = gawk ]; then
  apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq gawk >/dev/null 2>&1 || { echo "gawk install failed"; exit 1; }
  mkdir -p /tmp/shim && ln -s "$(command -v gawk)" /tmp/shim/awk
fi
mkdir -p /tmp/k && tar -x -C /tmp/k -f /k.tar && chown -R 1000:1000 /tmp/k
[ -d /tmp/shim ] && chown -R 1000:1000 /tmp/shim
setpriv --reuid=1000 --regid=1000 --clear-groups env HOME=/tmp PATH="/tmp/shim:$PATH" bash -c '
  cd /tmp/k
  echo "awk: $(awk -W version 2>/dev/null | head -1 || awk --version | head -1)"; echo "bash: $BASH_VERSION"; id -u
  tests/run-bats '"$files"
IN
