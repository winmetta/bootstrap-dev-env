# bootstrap-dev-env

Set up a development machine with one command: the [mise](https://mise.jdx.dev/) tool manager and the CLI tools it installs, shared git settings, a shell prompt and helpers, vim, and a terminal and editor. It is safe to re-run, skips what is already installed and never overwrites your own settings without asking.

| Platform | Status    |
| -------- | --------- |
| macOS    | supported |
| Linux    | planned   |
| Windows  | planned   |

Each platform is one file in [platforms/](platforms/), so adding one does not touch the shared steps. See [platforms/README.md](platforms/README.md).

## Use it

```bash
git clone https://github.com/winmetta/bootstrap-dev-env.git
cd bootstrap-dev-env
./bootstrap.sh              # add --containers to also install docker, colima and lima
```

Open a new terminal afterwards so mise takes effect, then sign in with `gh auth login`, `claude` and `codex`.

If a tool fails to install, the script keeps going and lists every failure with a manual fix at the end (exit code 1). Only the platform check, the platform prerequisites and mise stop it, because everything else depends on them. It asks a few questions when it has a terminal (your git name and email, whether git should use Zed or vim, whether to replace a `~/.config/starship.toml` that differs from the shared one). Without a terminal it skips them and prints a note.

## What it does (macOS)

1. Checks the platform and installs the Xcode Command Line Tools (`git`, `curl`, compiler). If it asks you to finish the installer, do that and re-run.
2. Installs mise and activates it in `~/.zshrc` and `~/.bashrc` (and makes `~/.bash_profile` load `~/.bashrc`, because Terminal.app starts bash as a login shell). Adds `~/.local/bin` and mise's shims to `PATH` in `~/.zprofile` (or `$ZDOTDIR/.zprofile`) so editors such as VS Code can find tools when running Git hooks. Respects `MISE_DATA_DIR` for the shims location. Fully quit and reopen the editor after running setup.
3. Installs the CLI tools with mise as global defaults, including Go, `just`, and GNU Coreutils, sed, grep, Findutils, Gawk, Diffutils, tar, patch, gzip and wget: the lists are [tools/mise-common.txt](tools/mise-common.txt) (every platform) and [tools/mise-macos.txt](tools/mise-macos.txt) (modern `bash`, `tree`). A project can pin another version with its own `mise.toml`. It warns when a copy of a tool outside mise comes first on `PATH`.
4. Checks that git has a `user.name` and `user.email`, suggesting your GitHub name and `<id>+<login>@users.noreply.github.com` address (it offers to run `gh auth login` first).
5. Installs shared git settings and aliases from [config/git/dev-env.gitconfig](config/git/dev-env.gitconfig) to `~/.config/git/bootstrap-dev-env.gitconfig`, included at the top of your global git config so your own settings win, and adds the patterns from [config/git/ignore](config/git/ignore) (such as `.DS_Store`) to your global ignore file.
6. Turns on zsh tab completion with zsh's own completion system (no framework): [config/shell/completion.zsh](config/shell/completion.zsh) gives `ls -<Tab>` and `git ch<Tab>` option and command suggestions with descriptions, and the script generates completion files into `~/.config/bootstrap-dev-env/completions/` for the installed tools that can print one (gh, docker, colima, uv, rg, fd, bat, pulumi, mise, ...). Its `source` line is appended to `~/.zshrc` like the others, and it registers zoxide's `z` completion itself, so the order of the lines does not matter. zsh only. Run `explain completion` for the keys.
7. Sets up the starship prompt in your shell startup files and keeps `~/.config/starship.toml` in step with [config/starship/starship.toml](config/starship/starship.toml): copied if you have none; if yours differs, it shows the diff and asks before replacing it (yours is backed up).
8. Hooks `zoxide` and `fzf` into your shell (`z <folder>`, Ctrl-R / Ctrl-T / Alt-C) with options and a long shared history from [config/shell/fzf.sh](config/shell/fzf.sh).
9. Installs the `explain-*` helpers from [config/shell/explain.sh](config/shell/explain.sh) and shell aliases from [config/shell/aliases.sh](config/shell/aliases.sh), under `~/.config/bootstrap-dev-env/`.
10. Configures vim: the shared [config/vim/.vimrc](config/vim/.vimrc) is sourced at the top of `~/.vimrc`, and the plugins in `VIM_PLUGINS` (`bootstrap.sh`) are installed as vim packages in `~/.vim/pack/bootstrap-dev-env/start/` (re-running updates them). GitHub Copilot needs a subscription and a one-time `:Copilot setup`; delete `~/.vim/pack/bootstrap-dev-env/start/copilot.vim` to opt out.
11. macOS extras: the JetBrains Mono Nerd Font into `~/Library/Fonts`, [iTerm2](https://iterm2.com/) and [Zed](https://zed.dev/) into `~/Applications` (no admin rights), the `bootstrap-dev-env` iTerm2 profile from [config/macos/iterm/dev-env.json](config/macos/iterm/dev-env.json) as the default, and the `zed` command linked into `~/.local/bin`. Quit iTerm2 before running the script, because it can overwrite its preferences on quit.
12. Asks whether git should open Zed (`zed --wait`) or vim for commit messages. An editor you already set is kept.
13. Installs this repo's git hooks with `lefthook install` ([lefthook.yml](lefthook.yml)): `shellcheck`, `shfmt`, `markdownlint-cli2`, `prettier --check`, a JSON check, a `gitleaks` secret scan, and a [Conventional Commits](https://www.conventionalcommits.org/) check on the message.
14. With `--containers`: installs `docker`, `docker-compose`, `colima` and `lima` ([tools/mise-containers.txt](tools/mise-containers.txt)) and links `docker-compose` into `~/.docker/cli-plugins`. No engine runs by default: start one with `colima start`.
15. Stops macOS from writing `.DS_Store` files on network shares and USB drives (applies after you log out and back in).
16. Installs the VS Code extensions listed in [config/vscode/extensions.txt](config/vscode/extensions.txt).

VS Code and Antigravity CLI have no mise package, so install them by hand and re-run the script. On a fresh machine the first run ends with a note that the VS Code CLI was not found. That is expected.

## Learn the tools you just installed

Open a new terminal, then:

```text
explain                  list every explain-* command with a one-line description
explain <name>           the same as explain-<name>: explain rg, explain git aliases
explain <tool> -x        only the lines about one option: explain rg -w
explain-tools            each tool the script installs: what it is and an example
explain-mise             what mise is, plus the everyday commands
explain-aliases          shell aliases such as ll, la and tree2
explain-git-aliases      git aliases with what they do
explain-git-config       the shared git settings with their current values
explain-command <cmd>    where a command comes from, and every copy on your PATH
explain-<tool>           a cheat sheet for one tool (explain-rg, explain-jq, ...)
```

Cheat sheets are one text file per tool in [config/shell/cheatsheets/](config/shell/cheatsheets/). To add one, drop a `<tool>.txt` file there and re-run the script.

The `prs` shell alias lists open pull requests in the current repository with their number, title, branch and full URL on its own line so terminals can make it clickable. It accepts `gh pr list` flags, for example `prs --state all`, `prs --author @me` or `prs -R <owner>/<repo>`. Run `explain aliases` to see its definition.

The GNU command catalog in [config/shell/gnu-tools.txt](config/shell/gnu-tools.txt) adds `explain <command>` and `explain-<command>` for every command in these GNU packages, including companion commands such as `sha256sum`, `updatedb`, `diff3` and `zgrep`. Each entry describes the command, shows an example and points to its GNU manual; a longer cheat sheet takes precedence when one exists. `explain coreutils`, `explain findutils` and `explain diffutils` describe the packages. Help includes upstream commands that are unavailable in some builds (for example SELinux tools on macOS), and marks deprecated wrappers such as `egrep`.

### GNU tools and command lookup

After installing or finding an existing GNU package, the bootstrap checks its main commands through `mise exec -- <command> --version`, including companion commands such as `awk`, `xargs`, `stat` and `date`. Missing commands and non-GNU implementations are recorded as failures in the final summary, even when package installation succeeds. These checks do not depend on the current shell having activated mise.

The explicit `conda:<package>` entries select the GNU projects from conda-forge, including **GNU Coreutils, not uutils** (mise's plain `coreutils` entry selects uutils). Packages expose their normal command names, including `awk` and `gawk`. They install under mise's data directory and do not replace system binaries. Native macOS utilities remain available by absolute path, such as `/usr/bin/sed`.

Open a new terminal to activate mise, or use `mise exec -- <command>` in scripts and noninteractive shells. For example:

```bash
mise exec -- ls --version
mise exec -- sed --version
mise exec -- awk --version
mise exec -- xargs --version
explain command sed             # inspect every copy on PATH
```

Aliases, shell functions and builtins can still take precedence over PATH. For builtins such as `echo`, `printf`, `pwd`, `test` and `[`, use `mise exec -- env <command>` when you specifically need the external GNU implementation. The bootstrap's initial setup continues to support native macOS tools and Bash 3.2 so it can install GNU tools on a fresh machine. OS-specific steps stay in the platform files; Linux support is still planned.

## Where it changes your machine

Everything the script writes, so you can review or undo it. Files it owns are replaced on every run; files you own only get a line added (never removed), and are never overwritten without asking.

**Files the script owns** (replaced on every run; edit the source in this repo instead):

| Path                                                                                  | What                                                                                                     | Source                                                             |
| ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `~/.config/bootstrap-dev-env/completion.zsh`                                          | zsh tab completion settings                                                                              | [config/shell/completion.zsh](config/shell/completion.zsh)         |
| `~/.config/bootstrap-dev-env/completions/_<tool>`                                     | completion scripts generated from the installed tools (gh, docker, uv, rg, ...); regenerated on each run | generated by `bootstrap.sh` (`COMPLETION_GENERATORS`)              |
| `~/.cache/zsh/zcompdump*`, `~/.cache/zsh/zcompcache/`                                 | zsh's completion cache; the dump is deleted and rebuilt when a completion file changes                   | created by zsh                                                     |
| `~/.config/bootstrap-dev-env/aliases.sh`                                              | shell aliases                                                                                            | [config/shell/aliases.sh](config/shell/aliases.sh)                 |
| `~/.config/bootstrap-dev-env/explain.sh`                                              | `explain-*` helpers                                                                                      | [config/shell/explain.sh](config/shell/explain.sh)                 |
| `~/.config/bootstrap-dev-env/gnu-tools.txt`                                           | GNU command descriptions and examples used by `explain` and `explain-tools`                              | [config/shell/gnu-tools.txt](config/shell/gnu-tools.txt)           |
| `~/.config/bootstrap-dev-env/cheatsheets/*.txt`                                       | one cheat sheet per tool (sheets removed from the repo stay until you delete them)                       | [config/shell/cheatsheets/](config/shell/cheatsheets/)             |
| `~/.config/bootstrap-dev-env/fzf.sh`                                                  | fzf options and shell history settings                                                                   | [config/shell/fzf.sh](config/shell/fzf.sh)                         |
| `~/.config/bootstrap-dev-env/.vimrc`                                                  | shared vimrc                                                                                             | [config/vim/.vimrc](config/vim/.vimrc)                             |
| `~/.config/git/bootstrap-dev-env.gitconfig`                                           | shared git settings and aliases                                                                          | [config/git/dev-env.gitconfig](config/git/dev-env.gitconfig)       |
| `~/.vim/pack/bootstrap-dev-env/start/`                                                | vim plugins, cloned from GitHub and updated on each run                                                  | `VIM_PLUGINS` in [bootstrap.sh](bootstrap.sh)                      |
| `~/Library/Application Support/iTerm2/DynamicProfiles/bootstrap-dev-env.json` (macOS) | iTerm2 profile                                                                                           | [config/macos/iterm/dev-env.json](config/macos/iterm/dev-env.json) |

**Files you own** (the script appends a line, or asks first):

| Path                                                                             | Change                                                                                                                                                                    |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `~/.zshrc` (or `$ZDOTDIR/.zshrc`) and `~/.bashrc`                                | appended once each: mise activation, starship, zoxide, fzf, and a `source` of `fzf.sh`, `explain.sh` and `aliases.sh`; in `~/.zshrc` only, a `source` of `completion.zsh` |
| `~/.bash_profile`                                                                | made to load `~/.bashrc` (created, or one line appended). If `~/.bash_login` or `~/.profile` is in use instead, it prints a note and leaves your files alone              |
| `~/.zprofile` (or `$ZDOTDIR/.zprofile`)                                          | appended once: adds `~/.local/bin` and `${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims` to `PATH` for login shells and editor Git hooks                                  |
| `~/.gitconfig` (or `~/.config/git/config` if it exists, or `$GIT_CONFIG_GLOBAL`) | an `[include]` of the shared gitconfig added at the top, so your own settings win; `user.name`, `user.email` and `core.editor` set only if missing                        |
| `~/.config/git/ignore` (or the file `core.excludesFile` points to)               | lines from [config/git/ignore](config/git/ignore) added if missing                                                                                                        |
| `~/.vimrc`                                                                       | `source ~/.config/bootstrap-dev-env/.vimrc` added at the top                                                                                                              |
| `~/.config/starship.toml` (or `$STARSHIP_CONFIG`)                                | copied if missing; if it differs, the script shows the diff and asks, and backs yours up to `starship.toml.bak-<date>` before replacing it                                |
| `~/.config/mise/config.toml`                                                     | tools added by `mise use -g`                                                                                                                                              |

**Installed software:**

| Path                                                         | What                                                                                |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `~/.local/bin/mise`                                          | mise itself (its installer); the tools it installs live under `~/.local/share/mise` |
| `~/.local/bin/zed` (macOS)                                   | link to the `zed` command inside `Zed.app`                                          |
| `~/Applications/iTerm.app`, `~/Applications/Zed.app` (macOS) | installed when missing from `/Applications` and `~/Applications`                    |
| `~/Library/Fonts/JetBrainsMonoNerdFont*.ttf` (macOS)         | the Nerd Font, when missing                                                         |
| `~/.docker/cli-plugins/docker-compose`                       | link to mise's `docker-compose`, only with `--containers`                           |
| `.git/hooks/` of this repo                                   | hooks written by `lefthook install`                                                 |

**Settings written with `defaults` (macOS):** `com.apple.desktopservices` `DSDontWriteNetworkStores` and `DSDontWriteUSBStores` (both true), and `com.googlecode.iterm2` `Default Bookmark Guid` (the profile above becomes the iTerm2 default).

**To undo it:** delete the files in the first table, remove the lines mentioning `bootstrap-dev-env` and the mise, starship, zoxide and fzf lines from your startup files, remove the `[include]` from your git config, and remove the `source` line from `~/.vimrc`.

## Change it

- **Add a tool:** add a `tool:command` line to [tools/mise-common.txt](tools/mise-common.txt) (or a platform list), add a line to `_explain_tools_data` in [config/shell/explain.sh](config/shell/explain.sh), and optionally a cheat sheet.
- **GNU command help:** update [config/shell/gnu-tools.txt](config/shell/gnu-tools.txt) (`package|command|description|example`); use a dedicated cheat sheet for a longer explanation. Examples are displayed as text and never executed. Run `bash scripts/test-gnu-tools.sh` to check coverage and help dispatch.
- **GNU verification:** `bash scripts/test-gnu-verification.sh` tests successful and missing commands, BSD/uutils fallbacks and re-runs without installing anything. Run it with `/bin/bash` on macOS to cover Bash 3.2.
- **Add a platform:** see [platforms/README.md](platforms/README.md).
- The scripts run on the bash 3.2 that ships with macOS: no associative arrays, `mapfile`, `${var,,}` or other bash 4+ features. `lefthook` checks `shellcheck -s bash` and `shfmt`.

CI ([.github/workflows/ci.yml](.github/workflows/ci.yml), job `checks`) runs the same checks on every pull request. The default-branch rules are in [rulesets/default.json](rulesets/default.json).

## Manual install

To install only Go with an existing mise installation, run `mise use -g go`, then check it with `go version`.

To install only the task runner with an existing mise installation, run `mise use -g just`. In a project with a `justfile`, use `just --list` to list its recipes and `just <recipe>` to run one.

Without the script, on macOS: install the Command Line Tools (`xcode-select --install`), mise (`curl -fsSL https://mise.run | sh`, then add `eval "$(~/.local/bin/mise activate zsh)"` to `~/.zshrc`), then `mise use -g <tool>` for each tool in the lists in [tools/](tools/). Copy the files from [config/](config/) to where `bootstrap.sh` puts them (the `*_DEST` variables at the top of it) and source them from `~/.zshrc`. For VS Code extensions, run `code --install-extension <id>` for each id in [config/vscode/extensions.txt](config/vscode/extensions.txt).
