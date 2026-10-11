# fzf and shell-history settings. bootstrap.sh copies this file
# to ~/.config/bootstrap-dev-env/fzf.sh and sources it from ~/.zshrc and ~/.bashrc, next to
# the `fzf --zsh` / `fzf --bash` line that binds Ctrl-R (history), Ctrl-T (files)
# and Alt-C (folders). Works in zsh and bash.

# Compact list under the prompt instead of full screen.
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border"

# Ctrl-R: press Ctrl-/ to show the whole command in a preview pane (long commands
# are cut off in the list). Enter pastes the chosen command; it does not run it.
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap:hidden --bind 'ctrl-/:toggle-preview'"

# Ctrl-R is only as good as the history behind it: keep a lot of it, share it
# between open terminals, and skip consecutive duplicates.
if [ -n "$ZSH_VERSION" ]; then
	HISTFILE="${HISTFILE:-${ZDOTDIR:-$HOME}/.zsh_history}"
	HISTSIZE=100000
	# shellcheck disable=SC2034 # zsh reads SAVEHIST; shellcheck only knows bash
	SAVEHIST=100000
	setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_FIND_NO_DUPS
elif [ -n "$BASH_VERSION" ]; then
	HISTSIZE=100000
	HISTFILESIZE=100000
	HISTCONTROL=ignoredups
	shopt -s histappend
fi
