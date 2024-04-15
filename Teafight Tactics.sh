#!/bin/sh
echo -ne '\033c\033]0;Teafight Tactics\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Teafight Tactics.x86_64" "$@"
