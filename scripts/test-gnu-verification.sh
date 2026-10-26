#!/usr/bin/env bash
# Exercise post-install GNU checks without installing tools or changing PATH.
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

mock_mise() {
	case "$1" in
	where) [[ "$MOCK_INSTALLED" == yes ]] ;;
	use) use_count=$((use_count + 1)) ;;
	exec)
		[[ "$2" == -- && "$4" == --version ]] || return 2
		[[ "$3" != "$MOCK_MISSING" ]] || return 127
		if [[ "$3" == "$MOCK_OTHER" ]]; then
			printf '%s\n' "$MOCK_OTHER_VERSION"
		else
			printf '%s\n' "$MOCK_VERSION"
		fi
		return "$MOCK_EXIT"
		;;
	*) return 2 ;;
	esac
}
find_mise() { printf '%s\n' mock_mise; }
warn_if_not_mise() { :; }

check_install() {
	local label="$1" entry="$2" expected_failures="$3" expected_installs="$4"
	FAILURES=()
	use_count=0
	mise_install_all "$entry" >/dev/null 2>&1
	if [[ ${#FAILURES[@]} != "$expected_failures" || "$use_count" != "$expected_installs" ]]; then
		printf 'FAIL %s: got %s failures and %s installs\n' "$label" "${#FAILURES[@]}" "$use_count" >&2
		exit 1
	fi
	printf 'PASS %s\n' "$label"
}

MOCK_INSTALLED=no MOCK_VERSION='sed (GNU sed) 4.10'
MOCK_MISSING='' MOCK_OTHER='' MOCK_OTHER_VERSION='BSD utility'
MOCK_EXIT=0
check_install 'fresh GNU install is verified through mise' conda:sed:sed 0 1
MOCK_INSTALLED=yes
check_install 'existing GNU install is still verified' conda:sed:sed 0 0
MOCK_EXIT=1
check_install 'version probe errors fail even with GNU output' conda:sed:sed 1 0
MOCK_EXIT=0

MOCK_OTHER='sed'
check_install 'existing package with BSD fallback fails verification' conda:sed:sed 1 0
MOCK_INSTALLED=no
check_install 'successful install with BSD fallback fails verification' conda:sed:sed 1 1

MOCK_INSTALLED=yes MOCK_OTHER='' MOCK_MISSING=grep
check_install 'missing command is recorded as non-fatal failure' conda:grep:grep 1 0

MOCK_MISSING='' MOCK_VERSION='ls (GNU coreutils) 9.12'
MOCK_OTHER=ls MOCK_OTHER_VERSION='ls (uutils coreutils) 0.5.0'
check_install 'uutils does not satisfy GNU Coreutils' conda:coreutils:ls 1 0

MOCK_OTHER='' MOCK_MISSING=xargs MOCK_VERSION='find (GNU findutils) 4.10.0'
check_install 'missing companion xargs is detected' conda:findutils:find 1 0
MOCK_MISSING=''
check_install 'all GNU Findutils companions pass verification' conda:findutils:find 0 0

MOCK_MISSING='' MOCK_VERSION='gzip 1.14: GNU General Public License'
check_install 'GNU gzip license identifies its implementation' conda:gzip:gzip 0 0
MOCK_OTHER=gzip MOCK_OTHER_VERSION='Apple gzip 1.14'
check_install 'non-GNU gzip fails verification' conda:gzip:gzip 1 0

MOCK_OTHER='' MOCK_MISSING=node
check_install 'unrelated packages do not require GNU banners' node@lts:node 0 0
