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
	'egrep'		# egrep(1)
)

# Source startup code
. /netctl/lib/bash/crt1.sh

################################################################################

usage()
{
	local -i rc=$?
	printf -- 'Usage: %s <into> <port_from> [<port_to>]\n' "$program_invocation_short_name" 2>&1
	exit $rc
}
declare -fr usage

# Exit in case of single command error;
# return error from single pipe command or zero if all success
set -e -o pipefail

# Check command line arguments
[ $# -eq 2 -o $# -eq 3 ] || usage

declare -ir into="$1"
[ "$into" -ge 0 -a "$into" -le 65535 ] 2>/dev/null || usage

declare -ir port_from="$2"
[ "$port_from" -ge 0 -a "$port_from" -le 65535 ] 2>/dev/null || usage

if [ $# -eq 3 ]; then
	declare -ir port_to="$3"
	[ "$port_to" -ge 0 -a "$port_to" -le 65535 ] 2>/dev/null || usage
fi

declare -r into_file="$into.conf"
declare -r into_file_tmp="$(mktemp -u "$into_file.XXXXXXXX")"

exit_handler()
{
	rm -f "$into_file_tmp"
}
trap 'exit_handler' EXIT

# Print header
printf -- '\n# %u\n' $into >"$into_file_tmp"

# Add new port, sort and uniq resulting output. Not delecting overlaps.
{
	printf -- 'aggregate %s into %u;\n' "${port_from}${port_to:+-$port_to}" $into
	[ ! -f "$into_file" -o ! -s "$into_file" ] ||
		egrep -vs "^([[:space:]]*|# $into)\$" "$into_file"
} |LC_ALL=C sort |LC_ALL=C uniq >>"$into_file_tmp"

# Install configuration file
mv -f "$into_file_tmp" "$into_file"
