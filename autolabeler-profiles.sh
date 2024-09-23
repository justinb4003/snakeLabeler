#!/usr/bin/env bash

# Source Credentials --- Note that this is not secure and will leak
# Goal is just to keep them off github
source .env
echo "$BLUESKY_HANDLE"
echo "$BLUESKY_APP_PASSWORD"

source settings.sh
process="PROFILE_AUTOLABELER"
logfile=autolabeler.log

log "Script started."

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
process="INGEST_DIDS"
log "Starting $MODULES/process_dids."
source "${MODULES}/process_dids"
log "Completed $MODULES/process_dids."

# Process Users
process="PROFILE_AUTOLABELER"
log "Starting $MODULES/process_users."

start=0
end=24

length=$(duckdb "$DATABASE" -json -c "
    SELECT COUNT(*) as count
    FROM unique_dids;
    " | jq -r '.[0].count')

log "$length unique dids observed."

while [ "$start" -le "$length" ]; do
    process_users
done

# Label Profiles
log "Starting $MODULES/label_profiles."
source "${MODULES}/label_profiles"




