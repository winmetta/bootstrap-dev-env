#!/usr/bin/env bash
# Run with /bin/bash on macOS to cover Bash 3.2, as well as a modern bash.
# Case bodies expand in the child shell, not in this test runner.
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_case() {
	local label="$1" expected="$2" code="$3" output status
	if output=$("$BASH" -c '
set -Eeuo pipefail
. "$1/lib/common.sh"
eval "$2"
' bash "$ROOT_DIR" "$code" 2>&1); then
		status=0
	else
		status=$?
	fi
	if [[ "$status" != "$expected" ]]; then
		printf 'FAIL %s: expected exit %s, got %s\n%s\n' "$label" "$expected" "$status" "$output" >&2
		exit 1
	fi
	if [[ "$expected" == 0 ]]; then
		if [[ -n "$output" ]]; then
			printf 'FAIL %s: unexpected diagnostic\n%s\n' "$label" "$output" >&2
			exit 1
		fi
	elif [[ "$output" != *"bootstrap-dev-env stopped at "*" (exit $expected)"* ]]; then
		printf 'FAIL %s: missing fatal diagnostic\n%s\n' "$label" "$output" >&2
		exit 1
	fi
	printf 'PASS %s\n' "$label"
}

check_case 'missing tool in conditional assignment' 0 '
missing_tool() { return 1; }
if ! result="$(missing_tool)"; then :; fi
'
check_case 'missing PATH command with fallback' 0 '
result="$(command -v bootstrap_missing_command_for_test)" || :
'
check_case 'missing preference in conditional comparison' 0 '
missing_preference() { return 1; }
if [[ "$(missing_preference)" == 1 ]]; then :; fi
'
check_case 'handled step failure' 0 '
attempt "test step" "retry manually" false >/dev/null 2>&1
[[ ${#FAILURES[@]} == 1 ]]
'
check_case 'unhandled function failure' 1 '
fail_step() { false; }
fail_step
printf "should not continue\n"
'
check_case 'unhandled command substitution failure' 7 '
result="$(exit 7)"
printf "should not continue\n"
'
