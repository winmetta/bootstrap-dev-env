# Platform-neutral steps: everything that works on any Unix with bash and mise.
# Sourced by bootstrap.sh after lib/common.sh and the platform file; not meant to
# be run directly. Must work on macOS's bash 3.2 (see bootstrap.sh).

# Append `eval "$(mise activate <shell>)"` to a startup file unless it already
# activates mise (any path), so re-runs and a later reinstall add no duplicates.
activate_mise_in() {
	local rc="$1" shell_name="$2" mise_bin="$3" activation
	activation="eval \"\$(\"$mise_bin\" activate $shell_name)\""
	mkdir -p "$(dirname "$rc")"
	if grep -q 'mise.*activate' "$rc" 2>/dev/null; then
		log_ok "mise already activated in $rc"
	else
		printf '%s\n' "$activation" >>"$rc"
		log_ok "activated mise in $rc"
	fi
}

# Terminal.app starts bash as a login shell, which reads ~/.bash_profile and
# never ~/.bashrc, so make the profile load ~/.bashrc. bash reads only the first
# of ~/.bash_profile, ~/.bash_login and ~/.profile, so if one of the latter two
# is in use, creating ~/.bash_profile would shadow it: leave a note instead.
ensure_bash_profile_loads_bashrc() {
	local profile="$HOME/.bash_profile" snippet='[ -f ~/.bashrc ] && . ~/.bashrc'
	if [[ -f "$profile" ]]; then
		if grep -q '\.bashrc' "$profile"; then
			log_ok "$profile already loads ~/.bashrc"
		else
			printf '\n%s\n' "$snippet" >>"$profile"
			log_ok "$profile now loads ~/.bashrc"
		fi
	elif [[ -f "$HOME/.bash_login" || -f "$HOME/.profile" ]]; then
		NOTES+=("bash reads ~/.bash_login or ~/.profile here, not ~/.bash_profile: add this line to that file so bash loads mise: $snippet")
	else
		printf '%s\n' "$snippet" >"$profile"
		log_ok "created $profile that loads ~/.bashrc"
	fi
}

install_mise() {
	log_step "mise (tool version manager)"
	local mise_bin
	if ! mise_bin="$(find_mise)"; then
		log_info "installing to ~/.local/bin/mise"
		# Runs the installer script published by mise; it is not pinned to a version.
		if ! curl -fsSL https://mise.run | sh; then
			die "mise failed to install. Install it by hand, then rerun: curl -fsSL https://mise.run | sh"
		fi
		mise_bin="$HOME/.local/bin/mise"
		log_ok "installed: $mise_bin"
	else
		log_ok "already installed: $mise_bin"
	fi

	# zsh is the macOS default shell; bash is configured too for people who use it.
	activate_mise_in "${ZDOTDIR:-$HOME}/.zshrc" zsh "$mise_bin"
	activate_mise_in "$HOME/.bashrc" bash "$mise_bin"
	ensure_bash_profile_loads_bashrc

	case "${SHELL##*/}" in
	zsh | bash) ;;
	*) NOTES+=("Your login shell is '${SHELL:-unknown}', which this script does not configure. Add mise activation to its startup file: $mise_bin activate <shell>") ;;
	esac
}

# Add the starship prompt to a startup file unless it is already set up there.
# Guarded by `command -v`, so the shell still starts if starship is missing; it
# must come after mise activation, which puts starship on PATH.
configure_starship_in() {
	local rc="$1" shell_name="$2" line
	line="command -v starship >/dev/null 2>&1 && eval \"\$(starship init $shell_name)\""
	if grep -q 'starship init' "$rc" 2>/dev/null; then
		log_ok "starship already set up in $rc"
	else
		printf '%s\n' "$line" >>"$rc"
		log_ok "set up starship in $rc"
	fi
}

configure_starship() {
	log_step "starship prompt"
	configure_starship_in "${ZDOTDIR:-$HOME}/.zshrc" zsh
	configure_starship_in "$HOME/.bashrc" bash
	attempt "install starship config" \
		"copy config/starship/starship.toml to '$STARSHIP_CONFIG_DEST'" \
		install_starship_config
}

# Keep ~/.config/starship.toml in step with the shared config. Missing: copy it.
# Identical: nothing to do. Different: show the diff and ask before replacing it
# (the old file is backed up first, only in this case). Non-interactive runs
# never replace it and leave a note instead.
install_starship_config() {
	local answer backup
	if [[ ! -e "$STARSHIP_CONFIG_DEST" ]]; then
		mkdir -p "$(dirname "$STARSHIP_CONFIG_DEST")" && cp "$STARSHIP_CONFIG_SRC" "$STARSHIP_CONFIG_DEST"
		log_info "copied the shared config to $STARSHIP_CONFIG_DEST"
		return
	fi
	if cmp -s "$STARSHIP_CONFIG_SRC" "$STARSHIP_CONFIG_DEST"; then
		log_ok "$STARSHIP_CONFIG_DEST is up to date"
		return
	fi
	log_info "$STARSHIP_CONFIG_DEST differs from the shared config (- yours, + shared):"
	diff -u "$STARSHIP_CONFIG_DEST" "$STARSHIP_CONFIG_SRC" | sed 's/^/      /' || true
	if [[ -t 0 ]]; then
		read -r -p "    Replace it with the shared config? Yours is backed up first. [y/N] " answer || answer=""
	else
		answer=""
	fi
	case "$answer" in
	[yY] | [yY][eE][sS])
		backup="$STARSHIP_CONFIG_DEST.bak-$(date +%Y%m%d-%H%M%S)"
		cp "$STARSHIP_CONFIG_DEST" "$backup" && cp "$STARSHIP_CONFIG_SRC" "$STARSHIP_CONFIG_DEST"
		log_info "backed up your config to $backup and installed the shared one"
		;;
	*)
		NOTES+=("$STARSHIP_CONFIG_DEST was left as is and differs from the shared config. To update it: cp '$STARSHIP_CONFIG_SRC' '$STARSHIP_CONFIG_DEST' (back up yours first).")
		;;
	esac
}

# Suggest an author from the signed-in GitHub account (needs `gh auth login`):
# "<name or login>" and the private "<id>+<login>@users.noreply.github.com"
# address, which GitHub links to the account without exposing a real email.
# Prints "name|email", or nothing when gh is missing or not signed in.
github_identity() {
	local id login name
	id="$(run_gh api user --jq .id 2>/dev/null)" || return 0
	login="$(run_gh api user --jq .login 2>/dev/null)" || return 0
	name="$(run_gh api user --jq '.name // empty' 2>/dev/null)" || name=""
	[[ -n "$id" && -n "$login" ]] || return 0
	echo "${name:-$login}|$id+$login@users.noreply.github.com"
}

# When gh is installed but not signed in, offer to run `gh auth login` now.
# Returns 0 only if gh is signed in afterwards.
offer_gh_login() {
	local answer
	run_gh --version >/dev/null 2>&1 || return 1
	run_gh auth status >/dev/null 2>&1 && return 0
	read -r -p "    gh is not signed in to GitHub. Sign in now to use your GitHub name and email? [Y/n] " answer || answer=n
	case "$answer" in
	[nN]*) return 1 ;;
	esac
	run_gh auth login && run_gh auth status >/dev/null 2>&1
}

# Make sure git has a commit author. Without user.name/user.email git guesses
# them from the OS user and hostname (e.g. "alo <alo@mac.local>"), which ends up
# in every commit. Missing values are looked up outside this clone (a repo-local
# identity does not count) and saved globally (all repos), suggesting the
# GitHub account's name and noreply email (offering to run `gh auth login` first
# if gh is not signed in); press Enter to
# accept the suggestion or type another value. Values already set (globally or
# in the repo) are left alone.
configure_git_identity() {
	log_step "git identity (user.name, user.email)"
	local key value suggestion label gh_identity=""
	local missing=0
	for key in name email; do
		if [[ -z "$(git_global_get "user.$key")" ]]; then
			missing=1
		fi
	done
	if ((missing)); then
		gh_identity="$(github_identity)"
		if [[ -z "$gh_identity" && -t 0 ]]; then
			offer_gh_login && gh_identity="$(github_identity)"
		fi
	fi
	for key in name email; do
		value="$(git_global_get "user.$key")"
		if [[ -n "$value" ]]; then
			log_ok "user.$key = $value"
			continue
		fi
		if [[ "$key" == name ]]; then
			suggestion="${gh_identity%%|*}" label="your full name"
		else
			suggestion="${gh_identity#*|}" label="your email"
		fi
		[[ -n "$gh_identity" ]] || suggestion=""
		if [[ -t 0 ]]; then
			read -r -p "    git user.$key is not set. Enter $label${suggestion:+ [$suggestion]} (blank to skip): " value || value=""
			value="${value:-$suggestion}"
		else
			value=""
		fi
		if [[ -n "$value" ]]; then
			attempt "set git user.$key" "git config --global user.$key '<value>'" \
				git config --global "user.$key" "$value"
		else
			NOTES+=("git user.$key is not set: run git config --global user.$key '<value>' (after gh auth login, re-running this script suggests your GitHub name and noreply email). Until then git guesses it from your OS user and hostname.")
		fi
	done
}

# Install the shared git settings and aliases. The file is copied to
# ~/.config/git/bootstrap-dev-env.gitconfig (replaced on every run, it is ours) and
# included at the TOP of the global git config, so your own settings further
# down still win.
install_git_config() {
	local tmp f
	mkdir -p "$(dirname "$GIT_CONFIG_DEST")" && cp "$GIT_CONFIG_SRC" "$GIT_CONFIG_DEST" || return 1
	# An include from an earlier run may sit in either file: do not add a second one.
	# ($GIT_CONFIG_GLOBAL replaces both files, so then only that one counts.)
	local files=("$GIT_GLOBAL_CONFIG")
	[[ -n "${GIT_CONFIG_GLOBAL:-}" ]] || files=("$GIT_GLOBAL_CONFIG" "$GIT_XDG_CONFIG" "$HOME/.gitconfig")
	for f in "${files[@]}"; do
		if [[ -e "$f" ]] && git config --file "$f" --get-all include.path 2>/dev/null | grep -qxF "$GIT_CONFIG_DEST"; then
			log_info "$f already includes it"
			return 0
		fi
	done
	tmp="$(mktemp)" || return 1
	{
		printf '[include]\n\tpath = %s\n\n' "$GIT_CONFIG_DEST"
		cat "$GIT_GLOBAL_CONFIG" 2>/dev/null || true
	} >"$tmp" && cat "$tmp" >"$GIT_GLOBAL_CONFIG"
	local rc=$?
	rm -f "$tmp"
	return $rc
}

# Add the patterns from git/ignore (such as .DS_Store) to your global ignore file:
# the one core.excludesFile already points to, else git's default
# ~/.config/git/ignore (which git reads without any setting). Lines you already
# have are left alone, and nothing is ever removed.
install_git_ignore() {
	local target line added=0
	target="$(git_global_get --type=path core.excludesFile)"
	[[ -n "$target" ]] || target="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
	mkdir -p "$(dirname "$target")" && touch "$target" || return 1
	while IFS= read -r line; do
		[[ -n "$line" && "$line" != \#* ]] || continue
		if ! grep -qxF -- "$line" "$target"; then
			# A last line without a newline would get glued to the new pattern.
			if [[ -s "$target" && -n "$(tail -c 1 "$target")" ]]; then printf '\n' >>"$target"; fi
			printf '%s\n' "$line" >>"$target" || return 1
			added=$((added + 1))
		fi
	done <"$GIT_IGNORE_SRC"
	log_info "global ignore file: $target ($added line(s) added)"
}

configure_git() {
	log_step "git settings and aliases"
	attempt "install git settings and aliases" \
		"copy config/git/dev-env.gitconfig to '$GIT_CONFIG_DEST' and add an [include] path for it at the top of ~/.gitconfig" \
		install_git_config
	attempt "ignore .DS_Store and friends in every repo" \
		"add the lines from config/git/ignore to ~/.config/git/ignore (or the file core.excludesFile points to)" \
		install_git_ignore
}

# Install the shared shell aliases (ll, la, tree2, ...): copy shell/aliases.sh to
# ~/.config/bootstrap-dev-env/aliases.sh (replaced on every run, it is ours) and source it
# from a startup file, once.
configure_aliases_in() {
	local rc="$1"
	if grep -qF "$ALIASES_DEST" "$rc" 2>/dev/null; then
		log_ok "aliases already sourced in $rc"
	else
		printf '%s\n' "[ -f \"$ALIASES_DEST\" ] && . \"$ALIASES_DEST\"" >>"$rc"
		log_ok "sourced the aliases in $rc"
	fi
}

install_aliases() {
	mkdir -p "$(dirname "$ALIASES_DEST")" && cp "$ALIASES_SRC" "$ALIASES_DEST" || return 1
	configure_aliases_in "${ZDOTDIR:-$HOME}/.zshrc"
	configure_aliases_in "$HOME/.bashrc"
}

configure_aliases() {
	log_step "shell aliases (ll, la, tree2, ...)"
	attempt "install shell aliases" \
		"copy config/shell/aliases.sh to '$ALIASES_DEST' and add '. $ALIASES_DEST' to ~/.zshrc and ~/.bashrc" \
		install_aliases
	log_info "Run 'explain-aliases' in a new terminal to see them."
}

# Zsh tab completion with nothing but zsh. config/shell/completion.zsh turns zsh's own
# completion system on (ls, git, grep, ssh, curl and tar already ship completion with
# macOS). The tools mise installs do not ship zsh completion, so each one that can print
# its own script is asked to, into $COMPLETIONS_DIR/_<tool>. The line that sources
# completion.zsh is appended to ~/.zshrc like every other line this script adds (nothing
# is rewritten); completion.zsh registers zoxide's `z` completion itself, so it does not
# matter whether it is sourced before or after the zoxide line.

# Source completion.zsh from a zsh startup file, once.
configure_completion_in() {
	local rc="$1"
	if grep -qF "$COMPLETION_DEST" "$rc" 2>/dev/null; then
		log_ok "zsh completion already sourced in $rc"
	else
		printf '%s\n' "[ -f \"$COMPLETION_DEST\" ] && . \"$COMPLETION_DEST\"" >>"$rc"
		log_ok "sourced the zsh completion setup in $rc"
	fi
}

# Print one tool's completion script into $COMPLETIONS_DIR/_<tool>, and say "changed",
# "same" or "skipped". Only output that starts with #compdef replaces the old file, so a
# generator that fails never clobbers a good one.
generate_completion_file() {
	local tool="$1" cmd="$2" tmp dest="$COMPLETIONS_DIR/_$1" result=skipped
	tmp="$(mktemp)" || return 1
	# shellcheck disable=SC2086 # $cmd is a short list of words
	if run_tool $cmd >"$tmp" 2>/dev/null && head -n 1 "$tmp" | grep -q '^#compdef'; then
		if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
			result=same
		elif cp "$tmp" "$dest"; then
			result=changed
		fi
	fi
	rm -f "$tmp"
	echo "$result"
}

install_completion() {
	local entry tool result changed=0 skipped="" cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
	mkdir -p "$COMPLETIONS_DIR" "$(dirname "$COMPLETION_DEST")" || return 1
	cp "$COMPLETION_SRC" "$COMPLETION_DEST" || return 1
	for entry in "${COMPLETION_GENERATORS[@]}"; do
		tool="${entry%%|*}"
		result="$(generate_completion_file "$tool" "${entry#*|}")" || result=skipped
		case "$result" in
		changed)
			changed=$((changed + 1))
			log_info "completion for $tool: written"
			;;
		same) ;;
		*) skipped="$skipped $tool" ;;
		esac
	done
	if [[ -n "$skipped" ]]; then
		log_info "no completion for:$skipped (not installed, or it cannot print one)"
	fi
	# zsh only sees a new or changed completion file after the cached dump is rebuilt.
	if ((changed > 0)); then
		rm -f "$cache"/zcompdump*
	fi
	configure_completion_in "${ZDOTDIR:-$HOME}/.zshrc"
}

configure_completion() {
	log_step "zsh tab completion (no framework)"
	attempt "set up zsh completion" \
		"copy config/shell/completion.zsh to '$COMPLETION_DEST' and add '. $COMPLETION_DEST' to ~/.zshrc" \
		install_completion
	log_info "Open a new terminal, then try: ls -<Tab>   git ch<Tab>   (see 'explain completion')."
}

# Install the explain-* shell helpers: copy shell/explain.sh to
# ~/.config/bootstrap-dev-env/explain.sh (replaced on every run, it is ours) and source it
# from a startup file.
configure_explain_in() {
	local rc="$1" line
	line="[ -f \"$EXPLAIN_DEST\" ] && . \"$EXPLAIN_DEST\""
	if grep -qF "$EXPLAIN_DEST" "$rc" 2>/dev/null; then
		log_ok "explain helpers already sourced in $rc"
	else
		printf '%s\n' "$line" >>"$rc"
		log_ok "sourced the explain helpers in $rc"
	fi
}

install_explain() {
	mkdir -p "$(dirname "$EXPLAIN_DEST")" && cp "$EXPLAIN_SRC" "$EXPLAIN_DEST" || return 1
	# One explain-<tool> cheat sheet per .txt file; sheets removed from the repo stay until you delete them.
	mkdir -p "$SHEETS_DEST" && cp "$SHEETS_SRC"/*.txt "$SHEETS_DEST/" || return 1
	configure_explain_in "${ZDOTDIR:-$HOME}/.zshrc"
	configure_explain_in "$HOME/.bashrc"
}

configure_explain() {
	log_step "shell helpers (explain-*)"
	attempt "install explain-* shell helpers" \
		"copy config/shell/explain.sh to '$EXPLAIN_DEST', config/shell/cheatsheets/*.txt to '$SHEETS_DEST', and add '. $EXPLAIN_DEST' to ~/.zshrc and ~/.bashrc" \
		install_explain
	log_info "Run 'explain' in a new terminal to list them."
}

# Choose the editor git opens for commit messages and interactive rebases: Zed
# (`zed --wait`, so git waits for you to close the tab) or vim. Asked once and
# saved globally in ~/.gitconfig; an editor you already set is left alone.
# Without a terminal, Zed is used if installed, else git's own default stays.
configure_git_editor() {
	log_step "git editor (Zed or vim)"
	local current default choice="" answer=""
	current="$(git_global_get core.editor)"
	if [[ -n "$current" ]]; then
		log_ok "core.editor = $current (already set; change it with: git config --global core.editor vim)"
		return
	fi
	if zed_available; then
		default=zed
	else
		default=vim
	fi
	if [[ -t 0 ]]; then
		read -r -p "    Editor for git commit messages: [z]ed or [v]im? [${default:0:1}] " answer || answer=""
		case "$answer" in
		[zZ]*) choice=zed ;;
		[vV]*) choice=vim ;;
		*) choice="$default" ;;
		esac
	elif [[ "$default" == zed ]]; then
		choice=zed
	fi
	case "$choice" in
	zed) attempt "set git editor to Zed" "git config --global core.editor 'zed --wait'" git config --global core.editor "zed --wait" ;;
	vim) attempt "set git editor to vim" "git config --global core.editor vim" git config --global core.editor vim ;;
	*) NOTES+=("git core.editor is not set: choose with git config --global core.editor 'zed --wait' (or vim).") ;;
	esac
}

# Install the git hooks from lefthook.yml into this repo's .git/hooks (pre-commit
# checks and the Conventional Commits message check). Safe to re-run; lefthook
# backs up any hook it did not create.
install_git_hooks() {
	local mise_bin
	if command -v lefthook >/dev/null 2>&1; then
		(cd "$ROOT_DIR" && lefthook install)
	elif mise_bin="$(find_mise)"; then
		(cd "$ROOT_DIR" && "$mise_bin" exec lefthook -- lefthook install)
	else
		return 1
	fi
}

configure_git_hooks() {
	log_step "git hooks (lefthook)"
	if [[ ! -f "$ROOT_DIR/lefthook.yml" ]]; then
		log_info "no lefthook.yml next to this script; skipping"
		return
	fi
	attempt "install git hooks" \
		"cd bootstrap-dev-env && lefthook install" \
		install_git_hooks
}

# Make `docker compose` (the form most docs use) work: Docker finds compose as a
# CLI plugin in ~/.docker/cli-plugins, so link mise's docker-compose binary there.
# The link goes through mise's "latest" folder, so it survives upgrades.
install_docker_compose_plugin() {
	local mise_bin dir src plugins="${DOCKER_CONFIG:-$HOME/.docker}/cli-plugins"
	mise_bin="$(find_mise)" || return 1
	dir="$("$mise_bin" where docker-compose 2>/dev/null)" || return 1
	src="$(dirname "$dir")/latest/docker-compose"
	[[ -x "$src" ]] || src="$dir/docker-compose"
	[[ -x "$src" ]] || return 1
	mkdir -p "$plugins" && ln -sfn "$src" "$plugins/docker-compose"
}

configure_docker() {
	((WITH_CONTAINERS)) || return 0
	log_step "docker compose plugin"
	attempt "link docker-compose as a docker CLI plugin" \
		"mkdir -p ~/.docker/cli-plugins && ln -sfn <mise docker-compose> ~/.docker/cli-plugins/docker-compose" \
		install_docker_compose_plugin
	log_info "No Docker engine runs by default: start one with 'colima start' (see 'explain colima')."
}

# Run vim from mise when it has one, else whatever vim is on PATH.
run_vim() {
	local mise_bin
	if mise_bin="$(find_mise)" && mise_has "$mise_bin" vim; then
		"$mise_bin" exec vim -- vim "$@"
	else
		vim "$@"
	fi
}

# Clone a plugin into the package dir, or fast-forward it if already there, then
# build its help tags.
install_vim_plugin() {
	local repo="$1" dir
	dir="$VIM_PACK_DIR/${repo#*/}"
	if [[ -d "$dir/.git" ]]; then
		git -C "$dir" pull --ff-only --quiet || return 1
	else
		mkdir -p "$VIM_PACK_DIR" && git clone --depth 1 --quiet "https://github.com/$repo.git" "$dir" || return 1
	fi
	if [[ -d "$dir/doc" ]]; then
		run_vim -u NONE -es -c "helptags $dir/doc" -c q || true
	fi
}

# Copy the shared vimrc to ~/.config/bootstrap-dev-env/.vimrc (replaced every run) and
# source it from the TOP of ~/.vimrc, so your own settings below it win.
install_vimrc() {
	local rc="$HOME/.vimrc" line tmp
	line="source $VIMRC_DEST"
	mkdir -p "$(dirname "$VIMRC_DEST")" && cp "$VIMRC_SRC" "$VIMRC_DEST" || return 1
	if grep -qxF "$line" "$rc" 2>/dev/null; then
		log_info "$rc already sources it"
		return 0
	fi
	tmp="$(mktemp)" || return 1
	{
		printf '%s\n\n' "$line"
		cat "$rc" 2>/dev/null || true
	} >"$tmp" && cat "$tmp" >"$rc"
	local status=$?
	rm -f "$tmp"
	return $status
}

configure_vim() {
	log_step "vim config and plugins"
	local repo
	attempt "install vimrc" \
		"copy config/vim/.vimrc to '$VIMRC_DEST' and add 'source $VIMRC_DEST' at the top of ~/.vimrc" \
		install_vimrc
	for repo in "${VIM_PLUGINS[@]}"; do
		attempt "vim plugin $repo" \
			"git clone https://github.com/$repo.git '$VIM_PACK_DIR/${repo#*/}'" \
			install_vim_plugin "$repo"
	done
	NOTES+=("GitHub Copilot for vim needs a sign-in and a Copilot subscription: open vim and run :Copilot setup. Remove ~/.vim/pack/bootstrap-dev-env/start/copilot.vim to opt out.")
}

# Turn on zoxide (smarter cd: `z <folder>`) and fzf (Ctrl-R history, Ctrl-T files,
# Alt-C folders) in a startup file. Each line is guarded by `command -v` and
# silences errors (a mise shim for a tool with no version set would otherwise
# print one in every new terminal), and is added only once.
configure_shell_tools_in() {
	local rc="$1" shell_name="$2" line
	if grep -q 'zoxide init' "$rc" 2>/dev/null; then
		log_ok "zoxide already set up in $rc"
	else
		line="command -v zoxide >/dev/null 2>&1 && eval \"\$(zoxide init $shell_name 2>/dev/null)\""
		printf '%s\n' "$line" >>"$rc"
		log_ok "set up zoxide in $rc"
	fi
	if grep -q 'fzf --' "$rc" 2>/dev/null; then
		log_ok "fzf already set up in $rc"
	else
		line="command -v fzf >/dev/null 2>&1 && eval \"\$(fzf --$shell_name 2>/dev/null)\""
		printf '%s\n' "$line" >>"$rc"
		log_ok "set up fzf in $rc"
	fi
	if grep -qF "$FZF_SH_DEST" "$rc" 2>/dev/null; then
		log_ok "fzf options already sourced in $rc"
	else
		printf '%s\n' "[ -f \"$FZF_SH_DEST\" ] && . \"$FZF_SH_DEST\"" >>"$rc"
		log_ok "sourced the fzf options in $rc"
	fi
}

# The fzf options and shell history settings are ours: replaced on every run.
install_fzf_options() {
	mkdir -p "$(dirname "$FZF_SH_DEST")" && cp "$FZF_SH_SRC" "$FZF_SH_DEST"
}

configure_shell_tools() {
	log_step "shell integration (zoxide, fzf)"
	attempt "install fzf options and history settings" \
		"copy config/shell/fzf.sh to '$FZF_SH_DEST'" \
		install_fzf_options
	configure_shell_tools_in "${ZDOTDIR:-$HOME}/.zshrc" zsh
	configure_shell_tools_in "$HOME/.bashrc" bash
}

# Prefer `code` on PATH; fall back to the CLI bundled in the app (platform_vscode_cli).
find_code() {
	if command -v code >/dev/null 2>&1; then
		command -v code
	else
		platform_vscode_cli
	fi
}

install_vscode_extensions() {
	log_step "VS Code extensions"
	local code_bin
	if ! code_bin="$(find_code)"; then
		record_failure "VS Code extensions (VS Code CLI not found)" "install VS Code, then re-run this script"
		return
	fi
	local installed ext extensions=()
	while IFS= read -r ext; do
		extensions+=("$ext")
	done < <(read_tool_list "$VSCODE_EXTENSIONS_FILE")
	installed="$("$code_bin" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')" || installed=""
	for ext in ${extensions[@]+"${extensions[@]}"}; do
		if grep -qxF "$(tr '[:upper:]' '[:lower:]' <<<"$ext")" <<<"$installed"; then
			log_ok "$ext already installed"
		else
			log_info "installing $ext"
			attempt "install extension $ext" "code --install-extension $ext" \
				"$code_bin" --install-extension "$ext" --force
		fi
	done
}

# Fill TOOL_ENTRIES with the entries of the given tool list files (bash 3.2 has no
# mapfile, and no namerefs to return an array).
collect_tools() {
	local file entry
	TOOL_ENTRIES=()
	for file in "$@"; do
		while IFS= read -r entry; do
			TOOL_ENTRIES+=("$entry")
		done < <(read_tool_list "$file")
	done
}

install_cli_tools() {
	log_step "CLI tools (installed with mise)"
	local platform_list
	platform_list="$(platform_tool_list)"
	collect_tools "$ROOT_DIR/tools/mise-common.txt" ${platform_list:+"$platform_list"}
	mise_install_all ${TOOL_ENTRIES[@]+"${TOOL_ENTRIES[@]}"}
	if ((WITH_CONTAINERS)); then
		log_step "Container tools (docker, docker-compose, colima, lima)"
		collect_tools "$ROOT_DIR/tools/mise-containers.txt"
		mise_install_all ${TOOL_ENTRIES[@]+"${TOOL_ENTRIES[@]}"}
	else
		NOTES+=("Container tools (docker, colima) were not installed. Add them with: ./bootstrap.sh --containers")
	fi
}
