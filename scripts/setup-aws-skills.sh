#!/usr/bin/env bash
# Install selected AWS skills for Codex (Universal) and Claude Code; keep existing copies.
# Usage: bash scripts/setup-aws-skills.sh <skill-name>...
# Compatible with macOS Bash 3.2. Run separately from the machine bootstrap.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

usage() {
	cat <<'USAGE'
Usage: bash scripts/setup-aws-skills.sh <skill-name>...

Install only the named skills from the official AWS catalog for Codex (Universal)
and Claude Code. Existing skill directories are preserved, including their versions.
Uses the mise-managed AWS CLI and the current AWS_PROFILE for catalog reads.
No login, MCP setup, project rules, updates or removals are performed.

Example: bash scripts/setup-aws-skills.sh aws-iam aws-serverless
USAGE
}

validate_skills() {
	local skill
	for skill in "$@"; do
		case "$skill" in
		"" | -* | *[!a-zA-Z0-9_-]*) die "Invalid skill name: $skill" ;;
		esac
	done
}

run_aws() {
	local mise_bin
	mise_bin="$(find_mise)" || {
		log_warn "mise not found; run bootstrap.sh first"
		return 1
	}
	# The catalog endpoint uses us-east-1, independently of the workload Region.
	"$mise_bin" exec -- aws "$@" --region us-east-1 --no-cli-pager --no-cli-auto-prompt
}

install_skill() {
	local skill="$1" agent="$2" root="$3" target
	target="$root/$skill"
	if [[ -e "$target" || -L "$target" ]]; then
		if [[ -f "$target/SKILL.md" ]]; then
			log_info "Keeping existing $skill for $agent: $target"
			return 0
		fi
		log_warn "$target exists without SKILL.md; inspect it before retrying"
		return 1
	fi
	run_aws agent-toolkit add-skill --skill-name "$skill" --agent "$agent" || return 1
	[[ -f "$target/SKILL.md" ]]
}

install_selected_skills() {
	local skill agent root
	for skill in "$@"; do
		for agent in universal claude-code; do
			case "$agent" in
			universal) root="$HOME/.agents/skills" ;;
			claude-code) root="$HOME/.claude/skills" ;;
			esac
			attempt "install $skill for $agent" \
				"bash scripts/setup-aws-skills.sh $skill (existing copies are kept)" \
				install_skill "$skill" "$agent" "$root"
		done
	done
}

main() {
	case "${1:-}" in
	-h | --help)
		usage
		return 0
		;;
	"")
		usage >&2
		return 2
		;;
	esac
	validate_skills "$@"
	# This local-only command also rejects CLI versions without toolkit support.
	run_aws agent-toolkit list-installed-skills >/dev/null || {
		log_warn "AWS toolkit commands unavailable; run mise use -g aws-cli@latest and retry"
		return 1
	}
	# Explicit agent directories make detection work even before the first agent launch.
	mkdir -p "$HOME/.agents/skills" "$HOME/.claude/skills"
	install_selected_skills "$@"
	if ((${#FAILURES[@]} > 0)); then
		printf '%s\n' "AWS skills setup had failures:" "${FAILURES[@]}" >&2
		return 1
	fi
	log_info "Selected AWS skills are present. Restart Codex and Claude Code to load them."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
