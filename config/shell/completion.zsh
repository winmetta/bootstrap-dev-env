# Zsh tab completion, using only what zsh ships with (no framework or plugin).
# bootstrap.sh copies this file to ~/.config/bootstrap-dev-env/completion.zsh and
# sources it from ~/.zshrc. zsh only; bash is not covered.
#
# What you get: `ls -<Tab>` lists the options with a one-line description, `git ch<Tab>`
# offers checkout and cherry-pick, and so on. Press Tab again to move through the menu
# with the arrow keys (Shift-Tab goes back), Enter accepts, Ctrl-G cancels.

zmodload zsh/complist

# Completion scripts the bootstrap generates for tools that do not ship their own
# (gh, docker, uv, rg, ...). They must be on fpath before compinit runs.
fpath=("$HOME/.config/bootstrap-dev-env/completions" $fpath)

_bde_init_completion() {
	emulate -L zsh
	setopt extended_glob
	autoload -Uz compinit
	local dump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
	mkdir -p "${dump:h}"
	# Rebuilding the dump is the slow part. Do it when it is missing or older than a day;
	# otherwise trust it (-C skips the check). The bootstrap deletes it when it adds or
	# updates a completion file, so new completions show up in the next terminal.
	if [[ -n $dump(#qN.mh-24) ]]; then
		compinit -C -d "$dump"
	else
		compinit -d "$dump"
	fi
}
_bde_init_completion
unfunction _bde_init_completion

# zoxide registers completion for `z` only if compinit has already run when its init line
# executes. If this file is sourced after that line, register it now.
(( $+functions[__zoxide_z_complete] )) && compdef __zoxide_z_complete z

# Arrow-key menu, with a description for every option and headings above each group.
zstyle ':completion:*' menu select
zstyle ':completion:*' verbose yes
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%B-- %d --%b%f'
zstyle ':completion:*:messages' format '%F{magenta}%d%f'
zstyle ':completion:*:warnings' format '%F{red}no matches for: %d%f'
# Match case-insensitively: ls -l and ls -L both find the option, README finds readme.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
# Complete . and .. and cache slow lookups (git branches, ssh hosts, ...).
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
# Colour the file names like ls does, when LS_COLORS is set.
[[ -n $LS_COLORS ]] && zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Do not stop with "do you wish to see all N possibilities?" (ls has over a hundred
# options). 0 means: ask only when the list would not fit on the screen, and with the menu
# above a long list scrolls instead.
LISTMAX=0
setopt complete_in_word always_to_end
bindkey '^[[Z' reverse-menu-complete
bindkey -M menuselect '^[[Z' reverse-menu-complete

# ssh, scp, sftp and rsync: also complete the host names written as `Host <name>` in
# ~/.ssh/config (zsh's own ssh completion only reads known_hosts and /etc/hosts).
# Read once per terminal; wildcard patterns such as `Host *` are skipped.
_bde_ssh_config_hosts() {
	emulate -L zsh
	setopt extended_glob
	[[ -r ~/.ssh/config ]] || return
	local -a hosts
	hosts=(${=${${(M)${(f)"$(<~/.ssh/config)"}:#[[:space:]]#[Hh]ost[[:space:]]##*}##[[:space:]]#[Hh]ost[[:space:]]##}})
	hosts=(${hosts:#*[\*\?\!]*})
	(( $#hosts )) && zstyle ':completion:*:(ssh|scp|sftp|rsync):*' hosts $hosts
}
_bde_ssh_config_hosts
unfunction _bde_ssh_config_hosts

# The AWS CLI completes through a bash-style helper that ships with it.
if (( $+commands[aws_completer] )); then
	autoload -Uz bashcompinit && bashcompinit
	complete -C "${commands[aws_completer]}" aws
fi
