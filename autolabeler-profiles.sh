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

    for i in $(seq 0 23); do
        log "Processing DIDs for hour $i."

        duckdb "$ROOT/tmp/tmp_$i.db" -c "
            CREATE TABLE unique_dids AS
            * FROM parquet('$ROOT/tmp/dids_$i.parquet');
        "
    done

    for i in $(seq 0 23); do
    length=$(duckdb "$DATABASE" -json -c "
    SELECT COUNT(*) as count
    FROM unique_dids;
    " | jq -r '.[0].count')

    start=0
    end=24

    log "$length unique dids observed in hour $i."

    while [ "$start" -le "$length" ]; do

        process_dids $i $start $end &
        pid$i=$!

        # Wait for every fourth process to finish
        if ((i % 4 == 3)); then
            wait ${pid[i - 3]}
            wait ${pid[i - 2]}
            wait ${pid[i - 1]}
            wait ${pid[i]}
        fi
    done
done

    # Ensure any remaining processes (if the total is not a multiple of 4) are waited for
    wait

    # Consolidate the processed DIDs
    duckdb "$DATABASE" -c "COPY reports FROM '$ROOT/tmp/reports_*.parquet';"
    #rm -f "$ROOT/tmp/reports_*.parquet"
    #rm -f "$ROOT/tmp/tmp_*.db"

    label_profiles
    create_reports
    update_lists

}

main

log "Script finished."

exit 0
