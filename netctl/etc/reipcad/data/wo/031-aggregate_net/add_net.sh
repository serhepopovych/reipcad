#!/bin/bash

# External tool dependencies, MUST always be defined,
# even if empty (e.g.: declare -a crt1_request_tools_list=())
declare -a crt1_request_tools_list=(
	'whois'		# whois(1)
	'aggregate'	# aggregate(1)
	'cat'		# cat(1)
	'mktemp'	# mktemp(1)
	'timeout'	# timeout(1)
	'mv'		# mv(1)
	'sort'		# sort(1)
	'uniq'		# uniq(1)
	'rm'		# rm(1)
	'sed'		# sed(1)
)

# Source startup code
. /netctl/lib/bash/crt1.sh

# Whois query host.
declare -r WHOIS_HOST='whois.ripe.net'

################################################################################

usage()
{
	local -i rc=$?
	printf -- 'Usage: %s <asn> [<peer_name>]\n' "$program_invocation_short_name" 2>&1
	exit $rc
}
declare -fr usage

# Exit in case of single command error;
# return error from single pipe command or zero if all success
set -e -o pipefail

# Check command line arguments
[ $# -eq 1 -o $# -eq 2 ] || usage

declare -ir asn="$1"
[ "$asn" -ge 0 -a "$asn" -le 4294967295 ] 2>/dev/null || usage

if [ $# -eq 2 ]; then
	declare -r peer_name="$2"
fi

declare -r aggregate_file="as$asn.conf"
declare -r aggregate_file_tmp="$(mktemp -u "$aggregate_file.XXXXXXXX")"

exit_handler()
{
	rm -f "$aggregate_file_tmp"
}
trap 'exit_handler' EXIT

declare prefix strip
declare -r route_sed_regex='^route:[[:space:]]+(([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}\/[[:digit:]]{1,2})$'

# Print header
printf -- '\n# AS%u%s\n' $asn "${peer_name:+ ($peer_name)}" >"$aggregate_file_tmp"

# Add new port, sort and uniq resulting output. Not delecting overlaps.
{
	# Collect and aggregate
	timeout 30s whois -h "${WHOIS_HOST:-whois.ripe.net}" -T route -i origin "AS$asn" |\
	sed -nEe"s/$route_sed_regex/\1/p" |\
	aggregate -q -t |\
		while read prefix; do
			strip="${prefix##*/}"
			printf -- 'aggregate %s strip %u;\n' "$prefix" "$strip"
		done
	[ ! -f "$aggregate_file" -o ! -s "$aggregate_file" ] ||
		egrep -vs "^([[:space:]]*|# AS$asn)\$" "$aggregate_file"
} |LC_ALL=C sort |LC_ALL=C uniq >>"$aggregate_file_tmp"

# Install configuration file
mv -f "$aggregate_file_tmp" "$aggregate_file"
