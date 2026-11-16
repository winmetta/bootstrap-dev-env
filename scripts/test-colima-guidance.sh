#!/usr/bin/env bash
# Check architecture-aware suggestions with mock probes; no VMs or host settings change.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=platforms/macos.sh
. "$ROOT_DIR/platforms/macos.sh"

log_info() { printf '%s\n' "$*"; }
log_warn() { printf '%s\n' "$*"; }
sw_vers() { printf '%s\n' "$MOCK_VERSION"; }
uname() { printf '%s\n' "$MOCK_ARCH"; }
sysctl() {
	[[ "$MOCK_ARM" != unavailable ]] || return 1
	printf '%s\n' "$MOCK_ARM"
}

check_hint() {
	local label="$1" expected="$2" output
	output="$(platform_colima_next_steps)"
	if [[ "$output" != *"$expected"* ]]; then
		printf 'FAIL %s: missing %s\n%s\n' "$label" "$expected" "$output" >&2
		return 1
	fi
	printf 'PASS %s\n' "$label"
}

main() {
	local output
	MOCK_VERSION=13.0 MOCK_ARCH=arm64 MOCK_ARM=1
	check_hint 'Apple Silicon uses native VZ with Rosetta' '--arch aarch64 --vm-type vz --vz-rosetta --activate=false'
	MOCK_ARCH=x86_64
	check_hint 'translated terminal still detects Apple Silicon hardware' '--arch aarch64 --vm-type vz --vz-rosetta --activate=false'
	MOCK_ARM=0
	check_hint 'Intel uses native VZ without Rosetta' '--arch x86_64 --vm-type vz --activate=false'
	MOCK_ARM=unavailable
	check_hint 'Intel tolerates an unavailable ARM sysctl' '--arch x86_64 --vm-type vz --activate=false'
	MOCK_ARCH=arm64
	check_hint 'native ARM uname is a fallback' '--arch aarch64 --vm-type vz --vz-rosetta --activate=false'
	MOCK_VERSION=12.7
	check_hint 'older macOS gets a support warning' 'Check Colima'
	output="$(platform_colima_next_steps)"
	[[ "$output" != *'colima start'* ]]
	MOCK_VERSION=unknown
	check_hint 'unknown macOS version gets a support warning' 'Check Colima'
	MOCK_VERSION=26.0 MOCK_ARCH=unknown
	check_hint 'unknown architecture gets a warning' 'Unknown Mac architecture'
	WITH_CONTAINERS=0
	output="$(platform_next_steps)"
	[[ "$output" != *'colima start'* ]]
	printf 'PASS suggestions are limited to --containers\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
