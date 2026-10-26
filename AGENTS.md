# AGENTS.md: bootstrap-dev-env

A platform-aware script that sets up a development machine: mise and the CLI tools it installs, git settings, shell and vim configuration, a prompt, a terminal and an editor. Supported platform: macOS. Linux and Windows are planned. The repo is generic: it must not mention any one organization or project in paths, names, comments or examples (use `<owner>/<repo>`, `~/projects`, `example.org`).

## Layout

- `bootstrap.sh`: entry point. Detects the OS, sources `lib/common.sh`, `platforms/<os>.sh` and `lib/steps.sh`, and runs the steps. `BOOTSTRAP_OS=<name>` forces a platform (for testing).
- `lib/common.sh`: logging, `attempt` / `record_failure`, mise helpers. `lib/steps.sh`: steps that work on any Unix with bash and mise.
- `platforms/<os>.sh`: only what mise cannot do on that OS. The function contract is in `platforms/README.md`. `bootstrap.ps1` is the Windows entry point (a stub for now).
- `tools/*.txt`: the tools mise installs, one `tool:command` per line.
- `config/`: files copied to the machine (git, shell, vim, starship, vscode, and `config/<os>/` for platform-only files). They land under `~/.config/bootstrap-dev-env/`.

## Rules

- **mise first.** Install a tool with mise whenever it is in the registry (`mise registry | grep <tool>`), on every platform. A platform file installs only system prerequisites, GUI apps, fonts and OS settings. Do not add `brew install` steps for something mise provides.
- **GNU utilities.** Prefer GNU Coreutils, sed, grep, Findutils, Gawk, Diffutils, tar, patch, gzip and wget for development commands. Use explicit `conda:<package>` entries: mise's plain `coreutils` resolves to uutils, not GNU Coreutils. Use mise activation or `mise exec -- <command>` so the GNU commands win on PATH, and verify with `--version`. Keep the bootstrap itself compatible with system utilities before installation; use platform files for OS-specific behavior and keep macOS/Bash 3.2 and Linux checks.
- **bash 3.2.** `bootstrap.sh`, `lib/` and `platforms/macos.sh` run on the bash that ships with macOS: no associative arrays, `mapfile`, `${var,,}`, `declare -n`, `readarray`. Empty arrays under `set -u` need `${arr[@]+"${arr[@]}"}`. Check with `shellcheck -s bash -x bootstrap.sh lib/*.sh platforms/*.sh scripts/*.sh` and `shfmt -d` (tabs, see `.editorconfig`).
- **Idempotent and non-destructive.** Re-running changes nothing that is already right. Never overwrite a file the user owns without asking and backing it up; shared files go in `~/.config/bootstrap-dev-env/` (replaced on every run) and are included from the user's own files.
- **Non-fatal failures.** Wrap a step in `attempt "<label>" "<manual fix>" <command>` so one failure is reported at the end instead of stopping the run. Only the platform check, prerequisites and mise stop it.
- **Adding a tool:** a line in `tools/mise-*.txt`, a line in `_explain_tools_data` in `config/shell/explain.sh`, optionally `config/shell/cheatsheets/<tool>.txt`. **Adding a platform:** follow `platforms/README.md`.
- **GNU command help:** maintain `config/shell/gnu-tools.txt` for every command in the GNU packages, including platform-specific and companion commands. Each row is `package|command|description|example`. Existing per-command cheat sheets take precedence in `explain`; catalog commands also appear in `explain-tools`.
- **Document every path you write.** A new file, appended rc line, `defaults write` or install location goes in the README section "Where it changes your machine" in the same change.
- Don't commit secrets. `gitleaks` runs in the hooks and in CI.
- Pin versions in CI from the source of truth (`mise latest <tool>`), not from memory.

## Commits and PRs

Conventional Commits (`<type>(<optional scope>): <description>`), enforced by the `lefthook` commit-msg hook and CI. Run the hooks (`lefthook install`) and fix failures rather than bypassing them. The default branch is squash-merged, so the PR title and description become the commit.
