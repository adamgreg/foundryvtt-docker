#!/bin/sh
# shellcheck disable=SC3010,SC3037
# SC3010 - busybox supports [[ ]]
# SC3037 - busybox echo supports flags

# Mimic the winston logging used in logging.js
log_debug() {
  if [[ "${CONTAINER_VERBOSE:-}" ]]; then
    echo -e "${LOG_NAME} | $(date +%Y-%m-%d\ %H:%M:%S) | [debug] $*"
  fi
}

log() {
  echo -e "${LOG_NAME} | $(date +%Y-%m-%d\ %H:%M:%S) | [info] $*"
}

log_warn() {
  echo -e "${LOG_NAME} | $(date +%Y-%m-%d\ %H:%M:%S) | [warn] $*"
}

log_error() {
  echo -e "${LOG_NAME} | $(date +%Y-%m-%d\ %H:%M:%S) | [error] $*"
}
