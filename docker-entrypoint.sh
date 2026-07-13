#!/bin/sh
set -eu

data_dir=/app/data
template_dir=/app/templates

mkdir -p \
    "$data_dir/downloads" \
    "$data_dir/lang" \
    "$data_dir/termbases" \
    "$data_dir/uploads"

# Ensure persistent database exists
if [ ! -f "$data_dir/terminologue.sqlite" ]; then
    echo "Initializing SQLite database from template"
    cp "$template_dir/terminologue.template.sqlite" "$data_dir/terminologue.sqlite"
fi

# Ensure persistent config exists
if [ ! -f "$data_dir/siteconfig.json" ]; then
    echo "Initializing siteconfig from template"
    cp "$template_dir/siteconfig.template.json" "$data_dir/siteconfig.json"
fi

# Only run init.js if .initialized is missing
if [ ! -f "$data_dir/.initialized" ]; then
    (cd /app/website && node init.js)
    touch "$data_dir/.initialized"
fi

"$@" &
child_pid=$!

trap 'kill -TERM "$child_pid" 2>/dev/null || true' TERM
trap 'kill -INT "$child_pid" 2>/dev/null || true' INT

set +e
wait "$child_pid"
status=$?
if kill -0 "$child_pid" 2>/dev/null; then
    wait "$child_pid"
    status=$?
fi
exit "$status"
