ARG ALPINE_VERSION=3.21
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache postgresql-client python3 py3-pip coreutils jq aws-cli

ADD run.sh /run.sh

VOLUME ["/data"]
CMD ["sh", "/run.sh"]
