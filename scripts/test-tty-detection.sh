#!/usr/bin/env bash
# Regression test for TTY detection in the docker exec/run wrapper templates.
#
# Bug: these templates hardcode `-ti` on `docker exec`/`docker run`, which
# fails whenever the wrapper script is invoked without a real TTY attached
# to stdin/stdout (piped output, cron, CI, `< /dev/null`, etc.) with:
#   "cannot attach stdin to a TTY-enabled container because stdin is not a terminal"
#
# This test renders each template with dummy values, points `docker` at a
# stub that just records its argv, and asserts:
#   - non-interactive invocation (no tty) never requests `-t`
#   - interactive invocation (real pty via `script`) still requests `-t`
#
# Usage: ./scripts/test-tty-detection.sh

set -euo pipefail

TEMPLATES=(
  "packages/cardano-node/files/nview.sh.gotmpl"
  "packages/cardano-node/files/txtop.sh.gotmpl"
  "packages/dingo/files/nview.sh.gotmpl"
  "packages/dingo/files/txtop.sh.gotmpl"
  "packages/cardano-cli/files/cardano-cli.sh.gotmpl"
)

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# Stub `docker` on PATH so we test flag construction without needing real
# containers/images.
cat > "$WORKDIR/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$DOCKER_STUB_LOG"
EOF
chmod +x "$WORKDIR/docker"
export PATH="$WORKDIR:$PATH"

render() {
  sed \
    -e 's/{{ \.Package\.Name }}/testpkg/g' \
    -e 's/{{ \.Package\.Version }}/1.0.0/g' \
    -e 's/{{ \.Context\.Network }}/preview/g' \
    -e "s|{{ \.Paths\.ContextDir }}|${WORKDIR}/ctx|g" \
    "$1"
}

# True if the captured docker argv includes a short flag token containing 't'
# (-t, -ti, -it). These scripts only ever use -i/-t among short flags, so
# this is an unambiguous check.
forced_tty() {
  grep -qE '^-[a-zA-Z]*t[a-zA-Z]*$' "$1" 2>/dev/null
}

# Run $1 under a real pty, logging the typescript to /dev/null. BSD/macOS
# `script` takes the command positionally; util-linux `script` requires -c
# and otherwise silently ignores extra positional args (exit 0, command
# never runs) instead of erroring, so the two forms are not interchangeable.
run_with_pty() {
  case "$(uname -s)" in
    Darwin|*BSD*)
      script -q /dev/null "$1"
      ;;
    *)
      script -qc "$1" /dev/null
      ;;
  esac
}

FAIL=0

check() {
  local template="$1"
  local rendered="$WORKDIR/rendered.sh"
  render "$template" > "$rendered"
  chmod +x "$rendered"

  # Case 1: non-interactive invocation (stdin/stdout not a tty)
  export DOCKER_STUB_LOG="$WORKDIR/args-noninteractive.log"
  : > "$DOCKER_STUB_LOG"
  set +e
  "$rendered" </dev/null >/dev/null 2>&1
  local rc=$?
  set -e

  if [[ ! -s "$DOCKER_STUB_LOG" ]]; then
    echo "ERROR [$template] non-interactive run never reached docker (exit $rc) — cannot judge -t"
    FAIL=1
  elif forced_tty "$DOCKER_STUB_LOG"; then
    echo "FAIL [$template] requested -t with no TTY attached (would break in cron/CI/pipes)"
    FAIL=1
  else
    echo "PASS [$template] no -t requested without a TTY"
  fi

  # Case 2: interactive invocation (real pty via `script`)
  export DOCKER_STUB_LOG="$WORKDIR/args-interactive.log"
  : > "$DOCKER_STUB_LOG"
  set +e
  run_with_pty "$rendered" >/dev/null 2>&1
  rc=$?
  set -e

  if [[ ! -s "$DOCKER_STUB_LOG" ]]; then
    echo "ERROR [$template] interactive run never reached docker (exit $rc) — cannot judge -t"
    FAIL=1
  elif forced_tty "$DOCKER_STUB_LOG"; then
    echo "PASS [$template] -t requested when a TTY is attached"
  else
    echo "FAIL [$template] did not request -t despite a TTY being attached (interactive UX regression)"
    FAIL=1
  fi
}

for t in "${TEMPLATES[@]}"; do
  check "$t"
done

echo ""
if [[ $FAIL -ne 0 ]]; then
  echo "TTY detection test FAILED"
  exit 1
else
  echo "TTY detection test PASSED"
  exit 0
fi
