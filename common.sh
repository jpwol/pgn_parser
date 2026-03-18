#!/usr/bin/env bash

RESET="\033[0m"
GREEN="\033[32m"
RED="\033[31m"
BLUE="\033[34m"
YELLOW="\033[33m"
BOLD="\033[1m"

print_header() {
    local title="$1"
    # local sep=$(printf '=%.0s' $(seq 1 ${#title}))
    printf "[${YELLOW}FILE${RESET}]: ${BOLD}${title}${RESET}\n"
}

print_info() {
  msg=$1
  printf "[${BLUE}INFO${RESET}]: ${msg}\n"
}

print_error() {
  msg=$1
  printf "[${BOLD}${RED}ERROR${RESET}]: ${msg}\n"
}

print_success() {
  msg=$1
  printf "[${GREEN}DONE${RESET}]: Took ${msg} seconds\n"
}

print_pipeline_success() {
  printf "[${GREEN}DONE${RESET}]: Pipeline took ${msg} seconds\n"
}
