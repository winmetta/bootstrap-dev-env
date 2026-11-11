#!/usr/bin/env bash
# Exercise selective AWS skill setup with mocked catalog calls and disposable files.
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/setup-aws-skills.sh
. "$ROOT_DIR/scripts/setup-aws-skills.sh"

TEST_SKILLS_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_SKILLS_ROOT"' EXIT
CALLS=()

run_aws() {
	[[ "$1" == agent-toolkit && "$2" == add-skill && "$3" == --skill-name && "$5" == --agent ]] || return 2
	CALLS+=("$4:$6")
	mkdir -p "$TEST_SKILLS_ROOT/$6/$4"
	printf 'catalog content\n' >"$TEST_SKILLS_ROOT/$6/$4/SKILL.md"
}

check_preservation() {
	local agent
	for agent in universal claude-code; do
		install_skill aws-iam "$agent" "$TEST_SKILLS_ROOT/$agent"
		printf 'locally maintained version\n' >"$TEST_SKILLS_ROOT/$agent/aws-iam/SKILL.md"
		install_skill aws-iam "$agent" "$TEST_SKILLS_ROOT/$agent"
		[[ "$(cat "$TEST_SKILLS_ROOT/$agent/aws-iam/SKILL.md")" == 'locally maintained version' ]]
	done
	[[ ${#CALLS[@]} == 2 && "${CALLS[0]}" == aws-iam:universal && "${CALLS[1]}" == aws-iam:claude-code ]]
	printf 'PASS selected skills install for both agents; reruns preserve existing content\n'
}

check_incomplete_directory() {
	mkdir -p "$TEST_SKILLS_ROOT/universal/incomplete"
	if install_skill incomplete universal "$TEST_SKILLS_ROOT/universal"; then
		printf 'FAIL incomplete directory was accepted\n' >&2
		return 1
	fi
	[[ ${#CALLS[@]} == 2 ]]
	printf 'PASS incomplete existing directories are not overwritten\n'
}

check_unrequested_skill() {
	mkdir -p "$TEST_SKILLS_ROOT/universal/unrequested"
	printf 'keep me\n' >"$TEST_SKILLS_ROOT/universal/unrequested/SKILL.md"
	install_skill aws-compute universal "$TEST_SKILLS_ROOT/universal"
	[[ "$(cat "$TEST_SKILLS_ROOT/universal/unrequested/SKILL.md")" == 'keep me' ]]
	printf 'PASS unrequested skills remain unchanged\n'
}

check_failure_continuation() {
	# Replace the file-writing helper to exercise dispatch without touching real skills.
	install_skill() {
		CALLS+=("$1:$2")
		[[ "$1" != broken ]]
	}
	CALLS=()
	FAILURES=()
	install_selected_skills broken aws-iam
	[[ ${#CALLS[@]} == 4 && ${#FAILURES[@]} == 2 && "${CALLS[3]}" == aws-iam:claude-code ]]
	printf 'PASS failures are recorded and later skills are still attempted\n'
}

check_arguments() {
	local name
	for name in ../escape --all 'bad name'; do
		if (validate_skills "$name") >/dev/null 2>&1; then
			printf 'FAIL accepted invalid skill name: %s\n' "$name" >&2
			return 1
		fi
	done
	validate_skills aws-iam aws-serverless
	printf 'PASS invalid names are rejected before any writes\n'
}

main() {
	check_arguments
	check_preservation
	check_incomplete_directory
	check_unrequested_skill
	check_failure_continuation
}

main "$@"
