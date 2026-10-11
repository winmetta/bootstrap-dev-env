#!/usr/bin/env bash
# Developer environment bootstrap. Safe to re-run.
#
# Sets up a machine for development: the tool manager mise and the CLI tools it
# installs, git settings, shell and vim configuration, the starship prompt, and the
# editor and terminal. Supported platform: macOS. Linux and Windows are planned
# (see platforms/README.md for how a platform plugs in).
#
# Compatibility: this must run on the bash 3.2 that ships with macOS (/bin/bash).
# Do not use associative arrays, mapfile/readarray, ${var,,} or ${var^^}, declare -n
# or other bash 4+ features. Check with: shellcheck -s bash bootstrap.sh lib/*.sh platforms/*.sh
#
# Layout:
#   lib/common.sh       logging, failure tracking, mise helpers
#   lib/steps.sh        steps that work on any Unix with bash and mise
#   platforms/<os>.sh   what mise cannot do on that OS (prerequisites, GUI apps, fonts, settings)
#   tools/*.txt         the tools mise installs, one "tool:command" per line
#   config/             the files copied to the machine
#
# Steps, in the order they run (see README.md for the details of each):
#   - platform prerequisites (macOS: Xcode Command Line Tools) and mise, the tool
#     manager, activated in ~/.zshrc and ~/.bashrc
#   - CLI tools, installed with mise (tools/mise-common.txt plus the platform's own
#     list). Containers without Docker Desktop are optional: add them with --containers
#   - git: author name and email (suggested from your GitHub account), shared
#     settings and aliases (config/git/dev-env.gitconfig), a global ignore file
#     (config/git/ignore), the commit-message editor (Zed or vim), and the lefthook
#     hooks of this repo
#   - shell: starship config, zoxide and fzf, the explain-* helpers with their
#     cheat sheets, aliases
#   - vim: the shared vimrc and the plugins in VIM_PLUGINS
#   - platform extras (macOS: fonts, iTerm2 profile, Zed, Finder preferences)
#   - the VS Code extensions listed in config/vscode/extensions.txt
#
# VS Code and Antigravity CLI have no mise package and are installed by hand. Only
# the steps everything else depends on (platform check, prerequisites, mise) stop the
# script. If any other tool fails to install, the script keeps going and lists every
# failure with a manual fix at the end (exit code 1).
#
# Project-specific setup (pinned runtime versions, dependencies, browsers) belongs to
# each project and is managed with mise there; run the project's own setup script
# afterwards.
#
# Usage: ./bootstrap.sh [--containers]
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="$HOME/.config/bootstrap-dev-env"

FZF_SH_SRC="$ROOT_DIR/config/shell/fzf.sh"
FZF_SH_DEST="$CONFIG_HOME/fzf.sh"
ALIASES_SRC="$ROOT_DIR/config/shell/aliases.sh"
ALIASES_DEST="$CONFIG_HOME/aliases.sh"
SHEETS_SRC="$ROOT_DIR/config/shell/cheatsheets"
SHEETS_DEST="$CONFIG_HOME/cheatsheets"
EXPLAIN_SRC="$ROOT_DIR/config/shell/explain.sh"
EXPLAIN_DEST="$CONFIG_HOME/explain.sh"
VIMRC_SRC="$ROOT_DIR/config/vim/.vimrc"
VIMRC_DEST="$CONFIG_HOME/.vimrc"
VIM_PACK_DIR="$HOME/.vim/pack/bootstrap-dev-env/start"
# "owner/repo" of vim plugins loaded at startup (vim 8+ native packages, no plugin manager).
VIM_PLUGINS=(
	tpope/vim-endwise
	tpope/vim-repeat
	tpope/vim-surround
	tpope/vim-unimpaired
	tpope/vim-commentary
	github/copilot.vim
)

GIT_IGNORE_SRC="$ROOT_DIR/config/git/ignore"
GIT_CONFIG_SRC="$ROOT_DIR/config/git/dev-env.gitconfig"
GIT_CONFIG_DEST="$HOME/.config/git/bootstrap-dev-env.gitconfig"
# The file that gets the [include] of the shared git settings. Git reads the XDG
# config (~/.config/git/config) first and ~/.gitconfig second, and later values win,
# so when the XDG file exists the include goes at the top of THAT file: the shared
# values then rank below your own settings in both files. Otherwise it goes at the
# top of ~/.gitconfig ($GIT_CONFIG_GLOBAL replaces both when it is set).
GIT_XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
if [[ -n "${GIT_CONFIG_GLOBAL:-}" ]]; then
	GIT_GLOBAL_CONFIG="$GIT_CONFIG_GLOBAL"
elif [[ -e "$GIT_XDG_CONFIG" ]]; then
	GIT_GLOBAL_CONFIG="$GIT_XDG_CONFIG"
else
	GIT_GLOBAL_CONFIG="$HOME/.gitconfig"
fi
STARSHIP_CONFIG_SRC="$ROOT_DIR/config/starship/starship.toml"
STARSHIP_CONFIG_DEST="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"
WITH_CONTAINERS=0
VSCODE_EXTENSIONS_FILE="$ROOT_DIR/config/vscode/extensions.txt"

# --- platform -----------------------------------------------------------------

# BOOTSTRAP_OS overrides detection (for testing a platform file): macos, linux.
detect_os() {
	if [[ -n "${BOOTSTRAP_OS:-}" ]]; then
		echo "$BOOTSTRAP_OS"
		return
	fi
	case "$(uname -s)" in
	Darwin) echo macos ;;
	Linux) echo linux ;;
	*) echo unsupported ;;
	esac
}

PLATFORM="$(detect_os)"
if [[ ! -f "$ROOT_DIR/platforms/$PLATFORM.sh" ]]; then
	echo "Unsupported platform: ${BOOTSTRAP_OS:-$(uname -s)}. Supported: macOS (Linux and Windows are planned; see platforms/README.md)." >&2
	exit 2
fi

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"
# shellcheck source=platforms/macos.sh
. "$ROOT_DIR/platforms/$PLATFORM.sh"
# shellcheck source=lib/steps.sh
. "$ROOT_DIR/lib/steps.sh"

print_summary() {
	local item
	if ((${#FAILURES[@]} == 0)); then
		printf '\n%sThe environment is ready.%s\n' "$c_green" "$c_off"
	else
		printf '\n%sFinished with %d problem(s):%s\n' "$c_red" "${#FAILURES[@]}" "$c_off" >&2
		for item in "${FAILURES[@]}"; do
			printf '  %s✖ %s%s\n      fix: %s\n' "$c_red" "${item%%|*}" "$c_off" "${item#*|}" >&2
		done
		log_info "Fix the items above by hand, or fix this script, then re-run it (it skips what is installed)."
	fi
	for item in "${NOTES[@]+"${NOTES[@]}"}"; do
		log_warn "$item"
	done
	platform_next_steps
	log_info "Open a new terminal so mise takes effect, then sign in with 'gh auth login', 'claude' and 'codex'."
	((${#FAILURES[@]} == 0))
}

usage() {
	cat <<'USAGE'
Usage: bootstrap.sh [--containers]

  --containers  also install docker, docker-compose, colima and lima
                (containers without Docker Desktop)
  -h, --help    show this help
USAGE
}

main() {
	local arg
	for arg in "$@"; do
		case "$arg" in
		--containers) WITH_CONTAINERS=1 ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			usage >&2
			exit 2
			;;
		esac
	done
	platform_check
	platform_prerequisites
	install_mise
	install_cli_tools
	configure_git_identity
	configure_git
	configure_starship
	configure_shell_tools
	configure_explain
	configure_aliases
	configure_vim
	platform_extras
	configure_git_editor
	configure_git_hooks
	configure_docker
	platform_settings
	install_vscode_extensions
	print_summary || exit 1
}

main "$@"
