#!/bin/sh
set -e
set -o pipefail

# Send heartbeat
if [ -n "$SFN_TASK_TOKEN" ]; then
  aws stepfunctions send-task-heartbeat --task-token "$SFN_TASK_TOKEN"
fi

# Variable defaults
: "${FILENAME_PREFIX:=snapshot}"
: "${S3_STORAGE_TIER:=STANDARD_IA}"
: "${DB_PORT:=5432}"

# Set up our output filenames
timestamp=$(date --iso-8601=seconds | tr -d ':-' | cut -c1-15)
filename="${FILENAME_PREFIX}-${timestamp}.sql.gz"
destination="/data/$filename"
s3_url="s3://${S3_BUCKET}/${S3_PREFIX}${filename}"

# Export the database
set -- -h "$DB_HOST" -U "$DB_USER" -p "$DB_PORT" -x -Fp --no-acl --no-owner -c --if-exists
if [ -n "$PGDUMP_OPTS" ]; then
  set -- "$@" $PGDUMP_OPTS
fi
set -- "$@" "$DB_NAME"
pgdump_opts=$(printf ' %s' "$@")
echo "About to export pgsql://$DB_HOST/$DB_NAME to $destination"
eval "pg_dump $pgdump_opts" | gzip > "$destination"
echo "Export to $destination completed"

# Send heartbeat
if [ -n "$SFN_TASK_TOKEN" ]; then
  aws stepfunctions send-task-heartbeat --task-token "$SFN_TASK_TOKEN"
fi

# Publish to S3
extra_metadata=""
if [ -n "$REQUESTOR" ]; then
    extra_metadata=",Requestor=$REQUESTOR"
fi
echo "About to upload $destination to $s3_url"
aws s3 cp "$destination" "$s3_url" --storage-class "$S3_STORAGE_TIER" --metadata "DatabaseHost=${DB_HOST},DatabaseName=${DB_NAME}${extra_metadata}" --no-progress
echo "Upload to $s3_url completed"

# Send activity success
if [ -n "$SFN_TASK_TOKEN" ]; then
  json_output=$(jq -cn --arg uri "$s3_url" '{"uri":$uri}')
  aws stepfunctions send-task-success --task-token "$SFN_TASK_TOKEN" --task-output "$json_output"
fi
