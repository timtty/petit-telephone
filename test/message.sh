#!/bin/sh
# Send a text message (SIP MESSAGE) from the simulated phone 555 to
# extension $1 (default 888) through the PBX, then show what arrived.
# Requires the test stack:
#   docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
to=${1:-888}
{
    printf 'call tone/milliwatt sms-%s\r\n' "$to"
    sleep 2
    printf 'quit\r\n'
} | nc 127.0.0.1 5038 >/dev/null
sleep 1
docker logs --since 5s petit-telephone-phones 2>&1 | grep -a 'MESSAGE from'
