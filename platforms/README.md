# Platforms

`bootstrap.sh` detects the OS (`uname -s`, or `BOOTSTRAP_OS=<name>` to force one) and sources `platforms/<name>.sh` between `lib/common.sh` and `lib/steps.sh`. A platform file only does what [mise](https://mise.jdx.dev/) cannot: system prerequisites, GUI apps, fonts and OS settings. Everything installable by mise goes in `tools/*.txt` instead.

| Platform | Status         | Entry point                                                 |
| -------- | -------------- | ----------------------------------------------------------- |
| macOS    | supported      | `platforms/macos.sh`                                        |
| Linux    | planned (stub) | `platforms/linux.sh`                                        |
| Windows  | planned (stub) | `bootstrap.ps1` (PowerShell, since bash steps do not apply) |

## The contract

A platform file defines these functions. `bootstrap.sh` calls them in this order, around the shared steps from `lib/steps.sh`:

| Function                 | Purpose                                                                                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `platform_check`         | Verify the OS and architecture; `die` with a clear message if unsupported.                                                                     |
| `platform_prerequisites` | Install what mise's installer needs (macOS: Xcode Command Line Tools; Linux: `curl`, `git` and a compiler through the distro package manager). |
| `platform_tool_list`     | Print the path of the platform's extra mise tool list (`tools/mise-<name>.txt`); print nothing for none.                                       |
| `platform_extras`        | Fonts, GUI apps and terminal profiles, run after vim and before the git editor choice.                                                         |
| `zed_available`          | Succeed if the Zed editor is available (used to choose the git commit editor).                                                                 |
| `platform_vscode_cli`    | Print the path of the VS Code CLI when `code` is not on PATH; fail if none.                                                                    |
| `platform_settings`      | OS preferences, run near the end.                                                                                                              |
| `platform_next_steps`    | Print follow-up steps for the final summary.                                                                                                   |

Helpers from `lib/common.sh` to use: `log_step`, `log_info`, `log_ok`, `log_warn`, `die`, `attempt <label> <manual fix> <command...>` (records a failure and keeps going), and the `NOTES` array.

## Adding a platform

1. Copy `platforms/macos.sh` to `platforms/<name>.sh` and replace the macOS-specific parts, keeping the function names.
2. Add `tools/mise-<name>.txt` for tools that need a different package on that OS.
3. Put platform-only config files under `config/<name>/`.
4. Make sure the shell startup files that `lib/steps.sh` edits (`~/.zshrc`, `~/.bashrc`) are the right ones for that OS.
5. Run `shellcheck -s bash` on the new file and update the table above and the README.
