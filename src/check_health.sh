#!/bin/sh
# shellcheck disable=SC3010
# SC3010 - busybox supports [[ ]]

if [[ "${FOUNDRY_ROUTE_PREFIX:-}" ]]; then
  STATUS_URL="http://localhost:${PORT}/${FOUNDRY_ROUTE_PREFIX}/api/status"
else
  STATUS_URL="http://localhost:${PORT}/api/status"
fi

/usr/bin/curl --cookie-jar healthcheck-cookiejar.txt \
  --cookie healthcheck-cookiejar.txt --insecure --fail --silent \
  "${STATUS_URL}" || exit 1
