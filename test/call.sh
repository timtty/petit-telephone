#!/bin/sh
# Call extension $1 (default 888) from the simulated phone 555, hold the
# call for a few seconds with a 1 kHz tone as the "voice", then hang up.
# Requires the test stack:
#   docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
to=${1:-888}
{
    printf 'call tone/milliwatt out-%s\r\n' "$to"
    sleep 6
    printf 'status sip\r\n'
    sleep 1
    printf 'drop *\r\n'
    sleep 1
    printf 'quit\r\n'
} | nc 127.0.0.1 5038
