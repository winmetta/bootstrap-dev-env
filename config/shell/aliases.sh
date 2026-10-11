# Shell aliases. bootstrap.sh copies this file to
# ~/.config/bootstrap-dev-env/aliases.sh and sources it from ~/.zshrc and ~/.bashrc.
# A line starting with "#:" directly above an alias is its description:
# `explain-aliases` prints it. Works in zsh and bash.

# shellcheck disable=SC2139 # the colour flag is meant to be expanded once, when each alias is defined

# Colour flag for ls: GNU ls wants --color, the BSD ls on macOS wants -G.
if command ls --color=auto -d . >/dev/null 2>&1; then
	_wm_color='--color=auto'
else
	_wm_color='-G'
fi

# --- Listing files ---
#: long list with human-readable sizes (K, M, G); hidden files not shown
alias ll="ls $_wm_color -lh"
#: list all files including hidden (dot) files, but not the . and .. entries
alias la="ls $_wm_color -A"
#: long list of everything, including hidden files such as .git and .env
alias lla="ls $_wm_color -lAh"
#: like lla, sorted by modified time with the newest file LAST (right above your prompt)
alias lt="ls $_wm_color -lAhtr"

# --- Directory trees (the tree command is installed by the bootstrap) ---
#: folder tree, 2 levels deep
alias tree2='tree -L 2'
#: folder tree, 3 levels deep
alias tree3='tree -L 3'
#: folder tree including hidden files, without .git and node_modules
alias treea="tree -a -I '.git|node_modules'"
#: folders only, 2 levels deep
alias treed='tree -d -L 2'
#: folder tree that skips whatever .gitignore ignores
alias treeg='tree --gitignore'

# --- Finder (macOS only) ---
if [ "$(uname -s)" = Darwin ]; then
	#: show dot files and hidden folders in Finder (restarts Finder; Cmd+Shift+. toggles it without a restart)
	alias showdotfiles='defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder'
	#: hide dot files and hidden folders in Finder again (restarts Finder)
	alias hidedotfiles='defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder'
fi

# --- Moving around ---
#: go up one folder
alias ..='cd ..'
#: go up two folders
alias ...='cd ../..'

unset _wm_color
