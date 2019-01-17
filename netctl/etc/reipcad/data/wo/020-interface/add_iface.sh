#!/bin/bash

# External tool dependencies, MUST always be defined,
# even if empty (e.g.: declare -a crt1_request_tools_list=())
declare -a crt1_request_tools_list=(
	'cat'		# cat(1)
	'mktemp'	# mktemp(1)
	'mv'		# mv(1)
	'sort'		# sort(1)
	'uniq'		# uniq(1)
	'rm'		# rm(1)
	'sed'		# sed(1)
)

# Source startup code
. /netctl/lib/bash/crt1.sh

################################################################################

usage()
{
	local -i rc=$?
	printf -- 'Usage: %s <iface> <peer_name> <my_asn> <their_asn>\n' \
		"$program_invocation_short_name" 2>&1
	exit $rc
}
declare -fr usage

# Exit in case of single command error;
# return error from single pipe command or zero if all success
set -e -o pipefail

# Check command line arguments
[ $# -eq 4 ] || usage

declare -r iface="$1"
declare -ir iface_size="${#iface}"
[ $iface_size -ge 0 -a $iface_size -le 15 ] 2>/dev/null || usage

declare -r peer_name="$2"
[ -n "$peer_name" ] || usage

declare -ir my_asn="$3"
[ "$my_asn" -ge 0 -a "$my_asn" -le 4294967295 ] 2>/dev/null || usage

declare -ir their_asn="$4"
[ "$their_asn" -ge 0 -a "$their_asn" -le 4294967295 ] 2>/dev/null || usage

declare -r iface_file="$iface.conf"
declare -r iface_file_tmp="$(mktemp -u "$iface_file.XXXXXXXX")"

exit_handler()
{
	rm -f "$iface_file_tmp"
}
trap 'exit_handler' EXIT

# Print header
printf -- '\n# %s (AS%s <-> AS%s)\n' "$peer_name" $my_asn $their_asn >"$iface_file_tmp"

# Add new iface
printf -- 'interface %s promisc;\n' "$iface" >>"$iface_file_tmp"

# Install configuration file
mv -f "$iface_file_tmp" "$iface_file"
