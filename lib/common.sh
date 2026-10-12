# Shared helpers: logging, failure tracking and mise helpers. Sourced by bootstrap.sh;
# not meant to be run directly. Must work on macOS's bash 3.2 (see bootstrap.sh).

# "what failed|how to fix it" lines, reported at the end.
FAILURES=()
# Follow-up steps the user must do by hand, reported at the end.
NOTES=()

# --- logging -----------------------------------------------------------------

if [[ -t 1 ]]; then
	c_blue=$'\033[34m' c_green=$'\033[32m' c_yellow=$'\033[33m' c_red=$'\033[31m' c_off=$'\033[0m'
else
	c_blue="" c_green="" c_yellow="" c_red="" c_off=""
fi
step=0
log_step() {
	step=$((step + 1))
	printf '\n%s==> [%d] %s%s\n' "$c_blue" "$step" "$*" "$c_off"
}
log_info() { printf '    %s\n' "$*"; }
log_ok() { printf '    %s✔ %s%s\n' "$c_green" "$*" "$c_off"; }
log_warn() { printf '    %s! %s%s\n' "$c_yellow" "$*" "$c_off" >&2; }
die() {
	printf '    %s✖ %s%s\n' "$c_red" "$*" "$c_off" >&2
	exit 1
}
trap 'printf "%s✖ bootstrap-dev-env stopped at line %s (exit %s)%s\n" "$c_red" "$LINENO" "$?" "$c_off" >&2' ERR

# Record a non-fatal failure and keep going.
record_failure() {
	FAILURES+=("$1|$2")
	log_warn "$1: failed; continuing (see summary at the end)"
}

# Run a command; on failure record it instead of stopping the script.
# Pass a single simple command: set -e does not apply inside an `if` condition.
attempt() {
	local label="$1" hint="$2"
	shift 2
	if "$@"; then
		log_ok "$label: ok"
	else
		record_failure "$label" "$hint"
		return 0
	fi
}

# A git setting as it applies outside any repository: the system and global files
# (both ~/.gitconfig and the XDG config), but not this clone's own .git/config.
# Used to decide whether a machine-wide setting is already there.
git_global_get() {
	(cd / && git config --get "$@" 2>/dev/null) || true
}

# Run gh from PATH, or through mise when this shell has not activated mise yet.
run_gh() {
	local mise_bin
	if command -v gh >/dev/null 2>&1; then
		gh "$@"
	elif mise_bin="$(find_mise)"; then
		"$mise_bin" exec gh -- gh "$@"
	else
		return 1
	fi
}

# Run a tool's command from PATH, or through mise when this shell has not activated
# mise yet. `mise` itself is found with find_mise.
run_tool() {
	local mise_bin
	if [[ "$1" == mise ]]; then
		shift
		mise_bin="$(find_mise)" || return 1
		"$mise_bin" "$@"
	elif command -v "$1" >/dev/null 2>&1; then
		"$@"
	elif mise_bin="$(find_mise)"; then
		"$mise_bin" exec -- "$@"
	else
		return 1
	fi
}

# Add LINE to the file RC before the first line that contains PATTERN, so it runs
# earlier; at the end when nothing matches. Does nothing when RC already has the line.
insert_before_in() {
	local rc="$1" pattern="$2" line="$3" tmp
	if grep -qxF -- "$line" "$rc" 2>/dev/null; then
		return 0
	fi
	if [[ -f "$rc" ]] && grep -qF -- "$pattern" "$rc"; then
		tmp="$(mktemp)" || return 1
		LINE="$line" PAT="$pattern" awk '!done && index($0, ENVIRON["PAT"]) { print ENVIRON["LINE"]; done = 1 } { print }' "$rc" >"$tmp" &&
			cat "$tmp" >"$rc"
		rm -f "$tmp"
	else
		printf '%s\n' "$line" >>"$rc"
	fi
}

# Prefer mise on PATH; fall back to the location the mise.run installer uses.
find_mise() {
	if command -v mise >/dev/null 2>&1; then
		command -v mise
	elif [[ -x "$HOME/.local/bin/mise" ]]; then
		echo "$HOME/.local/bin/mise"
	else
		return 1
	fi
}

# True if mise has the tool installed. A copy on PATH from elsewhere (e.g.
# Homebrew) does not count, so every tool ends up managed by mise.
mise_has() {
	"$1" where "${2%%@*}" >/dev/null 2>&1
}

# Install "tool:command" entries globally with mise, skipping tools mise already has.
mise_install_all() {
	local entry tool cmd mise_bin
	mise_bin="$(find_mise)" || {
		record_failure "CLI tools (mise not found)" "install mise, then re-run this script"
		return
	}
	for entry in "$@"; do
		tool="${entry%:*}" cmd="${entry##*:}"
		if mise_has "$mise_bin" "$tool"; then
			log_ok "$tool already installed with mise"
		else
			log_info "installing $tool"
			attempt "install $tool" "mise use -g $tool" "$mise_bin" use -g "$tool"
		fi
		warn_if_not_mise "$cmd"
	done
}

# Note when a command on PATH is not the mise-managed one (e.g. a Homebrew copy).
warn_if_not_mise() {
	local path
	path="$(command -v "$1" 2>/dev/null)" || return 0
	case "$path" in
	"$HOME"/.local/share/mise/*) ;;
	# macOS ships /usr/bin/python3, /bin/bash and friends: not removable, and mise's copy wins once mise is activated.
	/usr/bin/* | /bin/*) ;;
	*) NOTES+=("'$1' resolves to $path, not mise. Remove that copy (e.g. brew uninstall $1) so the mise one is used.") ;;
	esac
}

# Print the entries of a tool list file (tools/mise-*.txt): one "tool:command" per
# line, blank lines and "#" comments skipped.
read_tool_list() {
	local line
	[[ -f "$1" ]] || return 0
	while IFS= read -r line || [[ -n "$line" ]]; do
		case "$line" in
		"" | \#*) ;;
		*) printf '%s\n' "$line" ;;
		esac
	done <"$1"
}
