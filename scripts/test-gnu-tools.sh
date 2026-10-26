#!/usr/bin/env bash
# Validate GNU help coverage in Bash 3.2/5 and zsh without installing packages.
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT_DIR/config/shell/gnu-tools.txt"
seen=' '
count=0
while IFS='|' read -r package cmd desc example; do
	case "$package" in "" | \#*) continue ;; esac
	case "$package" in
	coreutils | sed | grep | findutils | gawk | diffutils | tar | patch | gzip | wget) ;;
	*)
		printf 'Unknown GNU package: %s\n' "$package" >&2
		exit 1
		;;
	esac
	# Names become function definitions: reject shell metacharacters except '['.
	case "$cmd" in
	'[') ;;
	'' | *[!a-z0-9-]*)
		printf 'Invalid command name: %s\n' "$cmd" >&2
		exit 1
		;;
	esac
	case "$seen" in *" $cmd "*)
		printf 'Duplicate command: %s\n' "$cmd" >&2
		exit 1
		;;
	esac
	[[ -n "$desc" && -n "$example" ]]
	seen="$seen$cmd "
	count=$((count + 1))
done <"$CATALOG"
[[ "$count" -gt 100 ]]

export EXPLAIN_SHEETS="$ROOT_DIR/config/shell/cheatsheets"
export EXPLAIN_GNU_TOOLS="$CATALOG"
test_shell="${1:-$BASH}"
# shellcheck disable=SC2016 # These expressions must expand in the selected shell.
"$test_shell" -c '
set -eu
. "$1/config/shell/explain.sh"
names=" $(_explain_sheet_names) "
tools="$(_explain_tools_data)"
while IFS="|" read -r package cmd desc example; do
	case "$package" in "" | \#*) continue ;; esac
	case "$names" in *" $cmd "*) ;; *) echo "Missing help listing: $cmd" >&2; exit 1 ;; esac
	type "explain-$cmd" >/dev/null
	result=$(explain "$cmd")
	case "$result" in "" | *"no cheat sheet"*) echo "Missing help: $cmd" >&2; exit 1 ;; esac
	printf "%s\n" "$tools" | grep -qF "$cmd|"
done < "$EXPLAIN_GNU_TOOLS"
explain date -d | grep -qF -- "-d"
explain sed | grep -qF -- "sed -i.bak"
explain coreutils | grep -qF "not the uutils"
explain findutils | grep -qF "GNU Findutils"
explain diffutils | grep -qF "GNU Diffutils"
explain > /dev/null
' bootstrap-gnu-tests "$ROOT_DIR"
printf 'PASS GNU catalog: %s commands, help dispatch and option filtering (%s)\n' "$count" "$test_shell"

# Check explicit GNU package selection and avoid duplicate platform entries.
for package in coreutils sed grep findutils gawk diffutils tar patch gzip wget; do
	matches=$(awk -F: -v package="$package" '$1 == "conda" && $2 == package { n++ } END { print n+0 }' "$ROOT_DIR"/tools/mise-*.txt)
	[[ "$matches" == 1 ]] || {
		printf 'Expected one conda:%s entry, got %s\n' "$package" "$matches" >&2
		exit 1
	}
done
if grep -q '^coreutils:' "$ROOT_DIR"/tools/mise-*.txt; then
	echo 'Plain coreutils selects uutils; use conda:coreutils' >&2
	exit 1
fi
printf 'PASS explicit GNU package selection\n'
