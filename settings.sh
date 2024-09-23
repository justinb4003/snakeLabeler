#!/usr/bin/env bash

PATH=/home/linuxbrew/.linuxbrew/bin/:$PATH

ROOT="$(dirname -- "${BASH_SOURCE[0]}")"            # relative
ROOT="$(cd -- "$ROOT" && pwd)"    # absolutized and normalized
if [[ -z "$ROOT" ]] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi
echo "$ROOT"
LOGPATH="$ROOT/logs"
echo "$LOGPATH"

MODULES="$ROOT/modules"
echo "$MODULES"

DATABASE="$ROOT/users.db"
echo "$DATABASE"

# Source Modules
source "$MODULES/auth"
source "$MODULES/functions"