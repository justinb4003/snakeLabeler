#!/usr/bin/env bash

# Source Credentials --- Note that this is not secure and will leak
# Goal is just to keep them off github
source .env
source config.sh

process="PROFILE_AUTOLABELER"
logfile=autolabeler.log

# Source Modules
source lib/auth
source lib/functions
source lib/label_profiles
source lib/create_reports
source lib/update_lists
source lib/process_dids
source lib/process_users

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

   length=$(duckdb "$DATABASE" -json -c "SELECT COUNT(*) as count FROM unique_dids;" | jq -r '.[0].count')

   start=0
   end=24

    log "$length unique dids observed."

    while [ "$start" -le "$length" ]; do
       process_users
   done

    # Label Profiles

    duckdb "$DATABASE" -c "CREATE OR REPLACE TABLE reports AS WITH new_reports AS (SELECT * FROM read_json('tmp/reports.json', format = 'newline_delimited')) SELECT * FROM reports UNION ALL (SELECT * FROM new_reports);"
    label_profiles
    create_reports
    update_lists

}

main

log "Script finished."

exit 0
