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

# Override persisted site settings when configured through the environment
if [ -n "${BASE_URL:-}" ] || [ -n "${ADMINS:-}" ]; then
    echo "Updating siteconfig from environment"
    SITECONFIG_PATH="$data_dir/siteconfig.json" node <<'NODE'
const fs = require("fs");

const configPath = process.env.SITECONFIG_PATH;
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));

if (process.env.BASE_URL) {
  const baseUrl = process.env.BASE_URL.trim();
  if (!baseUrl) {
    throw new Error("BASE_URL must not be blank");
  }
  config.baseUrl = `${baseUrl.replace(/\/+$/, "")}/`;
}

if (process.env.ADMINS) {
  const admins = process.env.ADMINS
    .split(",")
    .map((admin) => admin.trim())
    .filter(Boolean);

  if (admins.length === 0) {
    throw new Error("ADMINS must contain at least one admin");
  }
  config.admins = [...new Set(admins)];
}

fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
NODE
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
