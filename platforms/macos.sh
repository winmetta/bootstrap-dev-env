# macOS platform: what mise cannot do on a Mac (Command Line Tools, fonts, GUI
# apps in ~/Applications, Finder preferences). Sourced by bootstrap.sh; implements
# the platform contract described in platforms/README.md. Must work on the bash 3.2
# that ships with macOS.

VSCODE_APP="/Applications/Visual Studio Code.app"
FONT_DIR="$HOME/Library/Fonts"
ITERM_APPS=("/Applications/iTerm.app" "$HOME/Applications/iTerm.app")
ITERM_ZIP_URL="https://iterm2.com/downloads/stable/latest"
# shellcheck disable=SC2153 # ROOT_DIR is set by bootstrap.sh before this file is sourced
ITERM_PROFILE_SRC="$ROOT_DIR/config/macos/iterm/dev-env.json"
ITERM_PROFILE_DEST="$HOME/Library/Application Support/iTerm2/DynamicProfiles/bootstrap-dev-env.json"
# Must match "Guid" in config/macos/iterm/dev-env.json.
ITERM_PROFILE_GUID="2BF3B436-571F-4178-8AAA-B9F5FA7B45DA"
ZED_APPS=("/Applications/Zed.app" "$HOME/Applications/Zed.app")
DESKTOPSERVICES_DOMAIN="com.apple.desktopservices"

platform_check() {
	log_step "Checking platform"
	if [[ "$(uname -s)" != Darwin ]]; then
		die "This script supports macOS only. Install the tools listed in the README by hand."
	fi
	log_ok "macOS $(sw_vers -productVersion) ($(uname -m))"
}

platform_prerequisites() {
	log_step "Xcode Command Line Tools"
	if xcode-select -p >/dev/null 2>&1; then
		log_ok "already installed at $(xcode-select -p)"
		return
	fi
	log_info "starting installer"
	xcode-select --install || true
	die "Complete the Command Line Tools installer, then rerun this script."
}

# Path of an installed Zed.app (system-wide or in ~/Applications), if any.
find_zed_app() {
	local app
	for app in "${ZED_APPS[@]}"; do
		if [[ -d "$app" ]]; then
			echo "$app"
			return 0
		fi
	done
	return 1
}

# Download the latest stable Zed (the same dmg Zed's own install.sh uses) and copy
# Zed.app into ~/Applications (no admin rights needed). The dmg is always unmounted.
install_zed_app() {
	local arch tmp mount="" ok=1
	case "$(uname -m)" in
	arm64) arch=aarch64 ;;
	x86_64) arch=x86_64 ;;
	*) return 1 ;;
	esac
	tmp="$(mktemp -d)" || return 1
	if curl -fsSL -o "$tmp/Zed.dmg" "https://cloud.zed.dev/releases/stable/latest/download?asset=zed&os=macos&arch=$arch&source=install.sh" &&
		hdiutil attach -quiet -nobrowse -readonly -mountpoint "$tmp/mount" "$tmp/Zed.dmg" >/dev/null; then
		mount="$tmp/mount"
		mkdir -p "$HOME/Applications" && ditto "$mount/Zed.app" "$HOME/Applications/Zed.app" && ok=0
	fi
	[[ -n "$mount" ]] && hdiutil detach -quiet "$mount" >/dev/null 2>&1
	rm -rf "${tmp:?}"
	return $ok
}

# Link Zed's command-line tool as ~/.local/bin/zed (already on PATH via mise's installer).
link_zed_cli() {
	local app
	app="$(find_zed_app)" || return 1
	mkdir -p "$HOME/.local/bin" && ln -sf "$app/Contents/MacOS/cli" "$HOME/.local/bin/zed"
}

configure_zed() {
	log_step "Zed editor"
	if find_zed_app >/dev/null; then
		log_ok "Zed already installed at $(find_zed_app)"
	else
		log_info "downloading Zed (about 150 MB)"
		attempt "install Zed" \
			"download Zed from https://zed.dev/download and move Zed.app to ~/Applications" \
			install_zed_app
		find_zed_app >/dev/null || return 0
	fi
	attempt "link the zed command" \
		"ln -sf <path to Zed.app>/Contents/MacOS/cli ~/.local/bin/zed" \
		link_zed_cli
}

# True if the AWS Session Manager plugin is on PATH or already in ~/.local/bin.
session_manager_plugin_installed() {
	command -v session-manager-plugin >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/session-manager-plugin" ]]
}

# Download AWS's Session Manager plugin bundle (no mise package or admin rights
# needed; AWS's own installer wants sudo, but the binary runs from anywhere) and
# copy the binary to ~/.local/bin. `aws ssm start-session` needs it.
install_session_manager_plugin() {
	local arch tmp
	case "$(uname -m)" in
	arm64) arch=mac_arm64 ;;
	x86_64) arch=mac ;;
	*) return 1 ;;
	esac
	tmp="$(mktemp -d)" || return 1
	if curl -fsSL -o "$tmp/bundle.zip" "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$arch/sessionmanager-bundle.zip" &&
		unzip -q "$tmp/bundle.zip" -d "$tmp/bundle" &&
		mkdir -p "$HOME/.local/bin" &&
		cp "$tmp/bundle/sessionmanager-bundle/bin/session-manager-plugin" "$HOME/.local/bin/session-manager-plugin"; then
		rm -rf "${tmp:?}"
		return 0
	fi
	rm -rf "${tmp:?}"
	return 1
}

# The AWS CLI (installed by mise) cannot open `aws ssm start-session` without it.
configure_session_manager_plugin() {
	log_step "AWS Session Manager plugin"
	if session_manager_plugin_installed; then
		log_ok "session-manager-plugin already installed"
		return
	fi
	log_info "downloading the Session Manager plugin (about 4 MB)"
	attempt "install the AWS Session Manager plugin" \
		"download sessionmanager-bundle.zip from https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-macos-overview.html and copy bin/session-manager-plugin to ~/.local/bin" \
		install_session_manager_plugin
}

# Stop macOS from writing .DS_Store files on network shares and USB drives. (The
# global git ignore file hides them in git; this keeps them off other people's
# drives and servers in the first place.) Existing .DS_Store files are not
# removed, and the setting applies after you log out and back in.
configure_macos_defaults() {
	log_step "macOS: no .DS_Store files on network shares and USB drives"
	local key changed=0
	for key in DSDontWriteNetworkStores DSDontWriteUSBStores; do
		if [[ "$(defaults read "$DESKTOPSERVICES_DOMAIN" "$key" 2>/dev/null)" == 1 ]]; then
			log_ok "$key already on"
		else
			attempt "set $key" "defaults write $DESKTOPSERVICES_DOMAIN $key -bool true" \
				defaults write "$DESKTOPSERVICES_DOMAIN" "$key" -bool true
			if [[ "$(defaults read "$DESKTOPSERVICES_DOMAIN" "$key" 2>/dev/null)" == 1 ]]; then changed=1; fi
		fi
	done
	if ((changed)); then
		NOTES+=("Log out and back in (or restart) so macOS stops writing .DS_Store files on network shares and USB drives.")
	fi
}

# Download a font zip and copy its .ttf files into ~/Library/Fonts (per user, no
# admin rights). Skips static/ instances to avoid duplicate families. Skipped when
# a file matching the glob "$3" is already installed.
install_font_zip() {
	local label="$1" url="$2" installed_glob="$3" tmp file count=0
	if compgen -G "$FONT_DIR/$installed_glob" >/dev/null; then
		log_ok "$label already installed"
		return 0
	fi
	log_info "downloading $label"
	tmp="$(mktemp -d)" || return 1
	if ! curl -fsSL -o "$tmp/font.zip" "$url" || ! unzip -q "$tmp/font.zip" -d "$tmp/fonts"; then
		rm -rf "${tmp:?}"
		return 1
	fi
	mkdir -p "$FONT_DIR"
	while IFS= read -r -d '' file; do
		if ! cp "$file" "$FONT_DIR/"; then
			rm -rf "${tmp:?}"
			return 1
		fi
		count=$((count + 1))
	done < <(find "$tmp/fonts" -name '*.ttf' -not -path '*/static/*' -print0)
	rm -rf "${tmp:?}"
	if ((count == 0)); then
		return 1
	fi
	log_info "copied $count font file(s) to $FONT_DIR"
}

install_fonts() {
	log_step "Font (JetBrains Mono Nerd Font)"
	attempt "install JetBrains Mono Nerd Font" \
		"download JetBrainsMono.zip from https://github.com/ryanoasis/nerd-fonts/releases/latest and copy the .ttf files to ~/Library/Fonts" \
		install_font_zip "JetBrains Mono Nerd Font" \
		"https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
		'JetBrainsMonoNerdFont*.ttf'
}

# True if iTerm2 is installed system-wide or in ~/Applications.
iterm_installed() {
	local app
	for app in "${ITERM_APPS[@]}"; do
		[[ -d "$app" ]] && return 0
	done
	return 1
}

# Download the latest stable iTerm2 into ~/Applications (no admin rights needed).
# The URL redirects to the current iTerm2-<version>.zip; curl leaves no quarantine flag.
install_iterm_app() {
	local tmp dest="$HOME/Applications"
	tmp="$(mktemp -d)" || return 1
	if ! curl -fsSL -o "$tmp/iterm.zip" "$ITERM_ZIP_URL" || ! unzip -q "$tmp/iterm.zip" -d "$tmp/app"; then
		rm -rf "${tmp:?}"
		return 1
	fi
	mkdir -p "$dest"
	if ! cp -R "$tmp/app/iTerm.app" "$dest/"; then
		rm -rf "${tmp:?}"
		return 1
	fi
	rm -rf "${tmp:?}"
}

# Install iTerm2 if missing, add the "bootstrap-dev-env" profile as a Dynamic Profile
# (iTerm2 loads it without restarting) and make it the default profile. iTerm2
# may rewrite its preferences when it quits, so quit it before running this.
configure_iterm() {
	log_step "iTerm2 (app and bootstrap-dev-env profile)"
	if iterm_installed; then
		log_ok "iTerm2 already installed"
	else
		log_info "downloading iTerm2 (about 60 MB)"
		attempt "install iTerm2" \
			"download iTerm2 from https://iterm2.com/downloads.html and move iTerm.app to ~/Applications" \
			install_iterm_app
		if ! iterm_installed; then
			return
		fi
	fi
	attempt "install iTerm2 profile" \
		"copy config/macos/iterm/dev-env.json to '$ITERM_PROFILE_DEST'" \
		install_iterm_profile
	attempt "set bootstrap-dev-env as the default iTerm2 profile" \
		"iTerm2 > Settings > Profiles > bootstrap-dev-env > Other Actions > Set as Default" \
		defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$ITERM_PROFILE_GUID"
	if pgrep -x iTerm2 >/dev/null 2>&1; then
		NOTES+=("iTerm2 is running: if the bootstrap-dev-env profile is not the default for new windows, quit iTerm2 (Cmd+Q) and reopen it, or re-run this script with iTerm2 closed.")
	fi
}

install_iterm_profile() {
	mkdir -p "$(dirname "$ITERM_PROFILE_DEST")" && cp "$ITERM_PROFILE_SRC" "$ITERM_PROFILE_DEST"
}

# Is Zed available (on PATH, linked by this script, or installed as an app)?
zed_available() {
	command -v zed >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/zed" ]] || find_zed_app >/dev/null
}

# The VS Code CLI bundled in the app, for when `code` is not on PATH.
platform_vscode_cli() {
	[[ -x "$VSCODE_APP/Contents/Resources/app/bin/code" ]] || return 1
	echo "$VSCODE_APP/Contents/Resources/app/bin/code"
}

# Extra mise tool list for this platform.
platform_tool_list() {
	echo "$ROOT_DIR/tools/mise-macos.txt"
}

# Apps, fonts and OS settings, in the order they run.
platform_extras() {
	install_fonts
	configure_iterm
	configure_zed
	configure_session_manager_plugin
}

# Run after the platform-neutral steps (the git editor choice needs Zed first).
platform_settings() {
	configure_macos_defaults
}

# Printed at the end of the run.
platform_next_steps() {
	log_info "Apps with no mise package (VS Code, Antigravity CLI) are not installed by this script:"
	log_info "download them yourself, then re-run this script so it can install the VS Code extensions."
}
