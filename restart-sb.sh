#!/bin/bash

while true; do
    ./bskyLabeler-sb
    echo "Script stopped at $(date). Restarting..." >> ./logfile.log
    sleep 10  # Optional: Add a delay before restarting, e.g., 1 second
done