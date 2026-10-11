# "explain-*" shell helpers. bootstrap.sh copies this file to
# ~/.config/bootstrap-dev-env/explain.sh and sources it from ~/.zshrc and ~/.bashrc.
# Works in zsh and bash. Run `explain` to list them.

# explain <name> is the same as explain-<name>:  explain rg, explain ssh, explain tools,
# explain git aliases (= explain-git-aliases), explain command rg.
# explain <tool> <-option> shows only the lines about that option:  explain rg -w
# With no name it prints this list.
explain() {
	local name out opt
	case "${1:-}" in
	"" | -h | --help | help)
		_explain_help
		return 0
		;;
	esac
	name="$1"
	shift
	# explain git aliases  ->  explain-git-aliases
	if [ $# -gt 0 ] && type "explain-$name-$1" >/dev/null 2>&1; then
		name="$name-$1"
		shift
	fi
	if type "explain-$name" >/dev/null 2>&1; then
		case "${1:-}" in
		-*)
			# Only the lines that mention the option (plus the title line).
			opt="$(printf '%s' "$1" | sed 's/[][\\.*^$+?(){}|/]/\\&/g')"
			out="$("explain-$name" 2>&1)"
			printf '%s\n' "$out" | head -n 1
			if ! printf '%s\n' "$out" | tail -n +2 | grep -E -- "(^|[ ,(/'\"])$opt([ ,=)'\"]|$)"; then
				echo "no line about $1 in the $name cheat sheet (try: $name --help, or man $name)" >&2
				return 1
			fi
			;;
		*) "explain-$name" "$@" ;;
		esac
	elif command -v "$name" >/dev/null 2>&1; then
		echo "no cheat sheet for $name yet. Where it comes from:"
		explain-command "$name"
		echo "More: $name --help | man $name"
	else
		echo "nothing to explain for '$name'. Run explain with no arguments for the list." >&2
		return 1
	fi
}

_explain_help() {
	local b="" r="" all n listed=" " label names line others="" any
	if [ -t 1 ]; then
		b="$(printf '\033[1m')"
		r="$(printf '\033[0m')"
	fi
	all=" $(_explain_sheet_names) "
	printf '%sexplain%s: what is installed on this machine and how to use it\n\n' "$b" "$r"
	printf '%sUSAGE%s\n' "$b" "$r"
	cat <<'USAGE'
  explain                   this help (also: explain help, explain --help)
  explain <name>            the cheat sheet or explanation for <name> (same as explain-<name>)
  explain <tool> <-option>  only the lines about one option, e.g. explain rg -w
USAGE
	printf '\n%sSTART HERE%s\n' "$b" "$r"
	cat <<'START'
  explain tools             every tool the bootstrap installed: what it is and an example
  explain mise              what mise is, and the everyday commands (versions, switching, registry)
  explain aliases           shell aliases such as ll, la and tree2, each with what it runs
  explain git aliases       every git alias with a description and the command it runs
  explain git config        the shared git settings with their current values
  explain command <cmd>     where a command comes from: every copy on your PATH, and mise's
  explain path              your PATH, one folder per line, in lookup order
  explain starship          what the starship prompt is showing right now
START
	printf '\n%sCHEAT SHEETS%s  common commands and options, each with a comment\n' "$b" "$r"
	while IFS='|' read -r label names; do
		line=""
		for n in $(printf '%s\n' "$names"); do
			case "$all" in
			*" $n "*)
				line="$line $n"
				listed="$listed$n "
				;;
			esac
		done
		[ -n "$line" ] && printf '  %-17s%s\n' "$label" "$line"
	done <<'GROUPS'
search and files|rg fd sd bat tree find grep sed awk xargs jq fzf z
git and GitHub|git gh lefthook gitleaks
cloud|aws pulumi
containers|docker docker-compose colima
editors|vim
shell scripts|shellcheck shfmt
markdown|markdownlint prettier
languages|python node npm npx uv uvx
network|curl wget ssh scp rsync ssh-keygen ssh-copy-id ssh-add
system|df du top free ps kill lsof chmod tail diff tar gzip
macOS|security
GROUPS
	# Any sheet not named above (a newly added one) still shows up.
	for n in $(printf '%s\n' "$all"); do
		case "$listed" in
		*" $n "*) ;;
		*) others="$others $n" ;;
		esac
	done
	any="${others# }"
	[ -n "$any" ] && printf '  %-17s %s\n' "other" "$any"
	printf '\n%sALSO WORKS%s  alternative names such as keychain (= security), dh (= df), pkill, python3, zoxide\n' "$b" "$r"
	printf '\n%sEXAMPLES%s\n' "$b" "$r"
	cat <<'EXAMPLES'
  explain rg                the ripgrep cheat sheet
  explain rg -w             only the lines about the -w option
  explain git aliases       what each git alias does
  explain command node      which node runs, and from where
  explain kill              stopping a process, gently first
EXAMPLES
}

# command | what it is | example. Kept in a function, not in a $( ), because the
# bash 3.2 that ships with macOS cannot parse a heredoc with an apostrophe inside $( ).
_explain_tools_data() {
	cat <<'TOOLS'
mise|manages every tool below and their versions, instead of Homebrew or nvm|mise ls ; mise use -g <tool> ; mise latest <tool>
gh|GitHub from the terminal: clone, pull requests, issues, API calls|gh repo clone <owner>/<repo> ; gh pr create ; gh auth status
git|version control; shared settings and aliases are in ~/.config/git/bootstrap-dev-env.gitconfig|explain-git-aliases ; explain-git-config
shellcheck|finds bugs in shell scripts|shellcheck script.sh
shfmt|formats shell scripts consistently|shfmt -d script.sh   (diff) ; shfmt -w script.sh   (rewrite)
actionlint|checks GitHub Actions workflow files for mistakes before you push|actionlint ; actionlint .github/workflows/ci.yml
aws|the AWS command line; sign in with SSO, then s3, ec2, logs and any other service|aws sso login --profile NAME ; aws sts get-caller-identity ; aws s3 ls
gitleaks|scans for secrets (tokens, keys, passwords) in files and git history|gitleaks git --staged --redact ; gitleaks dir .
lefthook|runs the git hooks in lefthook.yml (checks before each commit, commit-message check)|lefthook install ; lefthook run pre-commit
markdownlint-cli2|checks Markdown files for style problems (rules in .markdownlint.json); --fix repairs what it can|markdownlint-cli2 README.md ; markdownlint-cli2 --fix README.md
prettier|formats Markdown (and JSON, CSS, JS, ...) where a repo has a prettier config|prettier --check README.md ; prettier --write README.md
claude|Claude Code, an AI coding agent|claude
codex|Codex CLI, an AI coding agent|codex
starship|the shell prompt: path, git branch, ahead/behind counts and a green check when synced|edit ~/.config/starship.toml ; explain-starship
node|JavaScript runtime (latest LTS; repos pin their own version)|node --version ; mise use node@22
pulumi|infrastructure as code: preview, then apply changes to real cloud resources|pulumi preview ; pulumi up ; pulumi stack ls
uv|fast Python package, project and tool manager (pip, venv and pipx in one); uvx runs a tool without installing it|uv init ; uv add requests ; uv run script.py ; uvx ruff --version
python3|Python 3 (latest stable; repos pin their own version)|python3 --version ; python3 -m venv .venv
vim|terminal editor with the shared ~/.config/bootstrap-dev-env/.vimrc and plugins (surround, commentary, Copilot)|vim file ; :help surround
bash|bash 5 (macOS ships 3.2): test scripts on both versions|bash --version ; /bin/bash --version
wget|download files from the web|wget https://example.com/file.zip
rg|ripgrep: fast text search that respects .gitignore (a better grep -r)|rg "TODO" ; rg -t py "import" ; rg -l foo
docker|builds and runs containers; needs an engine, which colima provides (no Docker Desktop)|docker run --rm hello-world ; docker ps ; docker logs -f NAME
docker-compose|runs several containers from one compose.yaml; also available as docker compose|docker compose up -d ; docker compose logs -f ; docker compose down
colima|starts the Linux VM with the Docker engine, as your user (no sudo)|colima start ; colima status ; colima stop
limactl|the Linux VM layer under colima; you rarely call it yourself|limactl list
fd|fast file finder with simple syntax (a better find)|fd readme ; fd -e md ; fd -t d src
jq|reads, filters and reshapes JSON|jq . file.json ; curl -s URL | jq '.items[].id'
tree|draws a folder as a tree; aliases tree2, tree3, treea, treed and treeg are shortcuts (see explain-aliases)|tree -L 2 ; tree2 ; treeg
sd|find and replace with normal regex, the same on macOS and Linux (a better sed)|sd 'old' 'new' file ; fd -e md -x sd 'a' 'b'
bat|cat with syntax highlighting and git markers|bat file ; bat -n file ; bat -l json
fzf|fuzzy finder: Ctrl-R history, Ctrl-T files, Alt-C folders|Ctrl-R ; git branch | fzf ; fd | fzf
zoxide|smarter cd that learns the folders you use|z projects ; z foo bar ; zi
iTerm|terminal app with the bootstrap-dev-env profile|open ~/Applications/iTerm.app
zed|Zed editor; its zed command is also git's commit-message editor|zed . ; zed --wait file
TOOLS
}

explain-tools() {
	local cmd desc try mark
	# Alphabetical, case ignored.
	_explain_tools_data | sort -f -t'|' -k1,1 | while IFS='|' read -r cmd desc try; do
		[ -n "$cmd" ] || continue
		if command -v "${cmd%% *}" >/dev/null 2>&1 || [ -d "/Applications/$cmd.app" ] || [ -d "$HOME/Applications/$cmd.app" ]; then
			mark="+"
		else
			mark="-"
		fi
		printf '%s %s\n    %s\n    try: %s\n\n' "$mark" "$cmd" "$desc" "$try"
	done
	echo "(+ installed, - not found on PATH; run the bootstrap script again to install what is missing)"
	echo "(a cheat sheet with common commands and options: explain-<tool>, e.g. explain-rg; run explain for the list)"
}

explain-git-aliases() {
	local file="$HOME/.config/git/bootstrap-dev-env.gitconfig" pairs="" names=" " name desc key value
	if [ -f "$file" ]; then
		# "name<TAB>description" for each "#: description" line above an alias in the shared config.
		pairs="$(awk '/^[[:space:]]*#:/ { sub(/^[[:space:]]*#:[[:space:]]*/, ""); d = $0; next }
			/^[[:space:]]+[A-Za-z0-9_-]+ = / { if (d != "") print $1 "\t" d; d = ""; next }
			{ d = "" }' "$file")"
	fi
	names="$names$(printf '%s\n' "$pairs" | cut -f1 | tr '\n' ' ')"
	printf '%s\n' "$pairs" | while IFS="$(printf '\t')" read -r name desc; do
		[ -n "$name" ] || continue
		printf '%s\n    %s\n    runs: %s\n\n' "$name" "$desc" "$(git config --get "alias.$name")"
	done
	# Aliases from your own config that have no description.
	git config --get-regexp '^alias\.' | while read -r key value; do
		name="${key#alias.}"
		case "$names" in *" $name "*) ;; *) printf '%s\n    runs: %s\n\n' "$name" "$value" ;; esac
	done
}

explain-git-config() {
	local file="$HOME/.config/git/bootstrap-dev-env.gitconfig" key desc
	[ -f "$file" ] || return 0
	# "section.key<TAB>description" for each "#: description" line above a setting.
	awk '/^\[[A-Za-z]+\]/ { s = tolower(substr($1, 2, length($1) - 2)); d = ""; next }
		s == "alias" { next }
		/^[[:space:]]*#:/ { sub(/^[[:space:]]*#:[[:space:]]*/, ""); d = $0; next }
		/^[[:space:]]+[A-Za-z0-9_-]+ = / { if (d != "") print s "." $1 "\t" d; d = ""; next }
		{ d = "" }' "$file" | while IFS="$(printf '\t')" read -r key desc; do
		printf '%s = %s\n    %s\n\n' "$key" "$(git config --get "$key")" "$desc"
	done
	echo "(values shown are what git uses now; anything set below the [include] in ~/.gitconfig or in a repo overrides the shared one)"
}

# Turn an alias value as printed by `alias` (already shell-quoted, and quoted
# differently by zsh and bash) back into the plain text you would type.
_explain_alias_value() {
	eval "printf '%s' $1"
}

explain-aliases() {
	local file="$HOME/.config/bootstrap-dev-env/aliases.sh" pairs="" names=" " name desc key value
	if [ -f "$file" ]; then
		# "name<TAB>description" for each "#: description" line above an alias.
		pairs="$(awk '/^[[:space:]]*#:/ { sub(/^[[:space:]]*#:[[:space:]]*/, ""); d = $0; next }
			/^[[:space:]]*alias / { n = $2; sub(/=.*/, "", n); if (d != "") print n "\t" d; d = ""; next }
			{ d = "" }' "$file")"
	fi
	names="$names$(printf '%s\n' "$pairs" | cut -f1 | tr '\n' ' ')"
	printf '%s\n' "$pairs" | while IFS="$(printf '\t')" read -r name desc; do
		[ -n "$name" ] || continue
		printf '%s\n    %s\n    runs: %s\n\n' "$name" "$desc" "$(_explain_alias_value "$(alias "$name" | sed -e 's/^alias //' -e 's/^[^=]*=//')")"
	done
	# Other aliases in this shell that have no description.
	alias | sed 's/^alias //' | while IFS='=' read -r key value; do
		case "$names" in *" $key "*) ;; *) printf '%s\n    runs: %s\n\n' "$key" "$(_explain_alias_value "$value")" ;; esac
	done
}

explain-mise() {
	cat <<'MISE'
mise is the tool and version manager for every repo. It installs and
switches Node, Python, gh, shellcheck and the other tools, one config file per
repo, instead of Homebrew or nvm. Your machine-wide defaults are in
~/.config/mise/config.toml; a repo's mise.toml wins inside that repo.

SEE WHAT YOU HAVE
  mise ls                     installed tools and where each version is set
  mise ls --current           only the tools active in this folder
  mise outdated               tools that have a newer version
  mise which node             the file that runs when you type node
  mise where node             the folder that version is installed in
  mise doctor                 diagnose a broken setup (PATH, shims, activation)

FIND WHAT EXISTS
  mise registry | grep <name> tool names mise knows, with where it installs from
  mise search <text>          search the registry
  mise ls-remote node         every available version of a tool
  mise latest node            the newest stable version (mise latest node@22 for a major)

INSTALL AND SWITCH VERSIONS
  mise use -g gh              install and make it your global default
  mise use node@22            pin Node 22 for THIS repo (writes mise.toml: commit it)
  mise use node@lts           follow a release channel instead of a number
  mise install                install everything this repo's mise.toml asks for
  mise x node@20 -- node -v   run one command with another version, nothing changes
  mise upgrade                move tools to their newest allowed version
  mise unuse node             remove a tool from the config, mise prune deletes unused copies

WATCH OUT FOR
  "No version is set for shim: <tool>"  the tool is installed but not in any config:
                                        run mise use -g <tool>
  Two copies of a tool (Homebrew and mise): explain-command <tool> shows which one runs.
  Docs: https://mise.jdx.dev   More in this shell: explain, explain-tools
MISE
}

explain-command() {
	if [ -z "$1" ]; then
		echo "usage: explain-command <command>" >&2
		return 1
	fi
	type -a "$1"
	if command -v mise >/dev/null 2>&1; then
		mise which "$1" 2>/dev/null | sed 's/^/mise: /'
	fi
}

explain-path() {
	printf '%s\n' "$PATH" | tr ':' '\n' | nl -w2 -s'  '
}

explain-starship() {
	starship explain
}

# --- Cheat sheets: one text file per tool in ~/.config/bootstrap-dev-env/cheatsheets ---
# Each <name>.txt becomes the command explain-<name>. To add one, drop a file in
# config/shell/cheatsheets/ and run the bootstrap (or copy it there).
_EXPLAIN_SHEETS="$HOME/.config/bootstrap-dev-env/cheatsheets"

_explain_sheet_names() {
	local f out=""
	# shellcheck disable=SC2045 # our own simple *.txt names; a glob would make zsh error out on an empty folder
	for f in $(ls "$_EXPLAIN_SHEETS" 2>/dev/null); do
		out="$out ${f%.txt}"
	done
	printf '%s' "${out# }"
}

_explain_cheatsheet() {
	if [ -f "$_EXPLAIN_SHEETS/$1.txt" ]; then
		cat "$_EXPLAIN_SHEETS/$1.txt"
	else
		echo "no cheat sheet for $1 (run the bootstrap script, or: ls $_EXPLAIN_SHEETS)" >&2
		return 1
	fi
}

# shellcheck disable=SC2045 # same reason as above: simple *.txt names, and zsh errors on an unmatched glob
for _explain_f in $(ls "$_EXPLAIN_SHEETS" 2>/dev/null); do
	eval "explain-${_explain_f%.txt}() { _explain_cheatsheet ${_explain_f%.txt}; }"
done
unset _explain_f

# Names people type for the same tool.
explain-zoxide() { explain-z; }
explain-python3() { explain-python; }
explain-ripgrep() { explain-rg; }
explain-dh() { explain-df; }
explain-head() { explain-tail; }
explain-pgrep() { explain-ps; }
explain-pkill() { explain-kill; }
explain-killall() { explain-kill; }
explain-zip() { explain-tar; }
explain-unzip() { explain-tar; }
explain-chown() { explain-chmod; }
explain-cmp() { explain-diff; }
explain-compose() { explain-docker-compose; }
explain-lima() { explain-colima; }
explain-limactl() { explain-colima; }
explain-keychain() { explain-security; }
explain-sshkeygen() { explain-ssh-keygen; }
explain-gunzip() { explain-gzip; }
explain-gzcat() { explain-gzip; }
explain-zcat() { explain-gzip; }
explain-sshadd() { explain-ssh-add; }
explain-sshcopyid() { explain-ssh-copy-id; }
explain-ssh-agent() { explain-ssh-add; }
