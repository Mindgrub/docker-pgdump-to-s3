# docker-pgdump-to-s3

An Alpine-based Docker image for producing a file with `pg_dump` and uploading it to Amazon S3.

There are tags for Alpine 3.20, 3.19, 3.18, and 3.17. This image is available on both the `linux/amd64` and `linux/arm64` platforms.

```bash
# The "latest" tag will always point to the most recent version of Alpine.
# Assuming 3.20.2 is most recent, these three commands all pull the same image.
docker pull @mindgrub/pgdump-to-s3:latest
docker pull @mindgrub/pgdump-to-s3:1-alpine-3.20
docker pull @mindgrub/pgdump-to-s3:1-alpine-3.20.2

# Pull other versions or architectures.
docker pull --platform linux/arm64 @mindgrub/pgdump-to-s3:1-alpine-3.18
```

## Environment Variables

- `DB_HOST` – Required. The hostname to which `pg_dump` will connect.
- `DB_PORT` – Optional. The TCP port to which `pg_dump` will connect (Default: "3306").
- `DB_NAME` – Required. The name of the database to dump.
- `DB_USER` – Required. The username to use to connect.
- `PGPASSWORD` – Required. The password to use to connect.
- `S3_BUCKET` – Required. The S3 bucket to store the exported file.
- `FILENAME_PREFIX` – Optional. A string to prepend to the exported file (Default: "snapshot").
- `S3_STORAGE_TIER` – Optional. The storage tier to use with S3 (Default: "STANDARD_IA").
- `S3_PREFIX` – Optional. A string to prepend to the S3 object key (Default: "").
- `PGDUMP_OPTS` – Optional. Additional command line options to provide to `pg_dump`.
- `REQUESTOR` – Optional. The email address of the user who requested this dump to be stored in the S3 metadata.
- `SFN_TASK_TOKEN` – Optional. A Step Functions [Task Token](https://docs.aws.amazon.com/step-functions/latest/apireference/API_GetActivityTask.html#StepFunctions-GetActivityTask-response-taskToken). If present, this token will be used to call [`SendTaskHeartbeat`](https://docs.aws.amazon.com/step-functions/latest/apireference/API_SendTaskHeartbeat.html) and [`SendTaskSuccess`](https://docs.aws.amazon.com/step-functions/latest/apireference/API_SendTaskSuccess.html). The task output sent to `SendTaskSuccess` will consist of a JSON object with a single property: `uri` (containing the S3 URI of the database dump).

### AWS Permissions

If this Docker image is used within Amazon ECS, specify permissions to S3 (and optionally Step Functions) within your Task Definition role. Otherwise, you can provide `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as environment variables.

## Technical Details

The following CLI arguments are included in the call to `pg_dump`: `-x -Fp --no-acl --no-owner -c --if-exists`. Use the `PGDUMP_OPTS` environment variable to specify additional options.

The database host, database name, and requestor are all added to the S3 object metadata.

The pattern for the final S3 object URL is: `s3://${S3_BUCKET}/${S3_PREFIX}${FILENAME_PREFIX}-${timestamp}.sql.gz`, where `$timestamp` is an ISO 8601 date and time with symbols removed (e.g. _20220202T160142_).
