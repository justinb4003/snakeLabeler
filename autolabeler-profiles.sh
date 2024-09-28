#!/usr/bin/env bash

# Source Credentials --- Note that this is not secure and will leak
# Goal is just to keep them off github
source .env
source config.sh

process="PROFILE_AUTOLABELER"
logfile=autolabeler.log

# Source Modules
source "$MODULES/auth"
source "$MODULES/functions"
source "$MODULES/label_profiles"
source "$MODULES/create_reports"
source "$MODULES/update_lists"
source "$MODULES/process_dids"
source "$MODULES/process_users"

log "Script started."

function main {

    # Fetch the access JWT
    log "Authenticating with Bluesky."
    auth "$BLUESKY_HANDLE" "$BLUESKY_APP_PASSWORD"

    # Initialize variables for rate limiting
    LABEL_LIMIT_REMAINING=3000
    LABEL_LIMIT_RESET=0

    # Previous Day's Date
    today=$(date -d "$date -1 days" +"%Y-%m-%d")
    file="dids_${today}.json"

    # Process DIDS
    process_dids

    length=$(duckdb "$DATABASE" -json -c "
    SELECT COUNT(*) as count
    FROM unique_dids;
    " | jq -r '.[0].count')

    start=0
    end=24

    log "$length unique dids observed."

    while [ "$start" -le "$length" ]; do
        process_users
    done

    label_profiles
    create_reports
    update_lists

}

main

log "Script finished."

exit 0
