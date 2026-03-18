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
  local msg=$1
  printf "[${BLUE}INFO${RESET}]: ${msg}\n"
}

print_error() {
  local msg=$1
  printf "[${BOLD}${RED}ERROR${RESET}]: ${msg}\n"
}

print_success() {
  local msg=$1
  printf "[${GREEN}DONE${RESET}]: Took ${msg} seconds\n"
}

print_pipeline_success() {
  local msg=$1
  printf "[${GREEN}DONE${RESET}]: Pipeline took ${msg} seconds\n"
}

print_completion() {
  print_info "Pipeline completed successfully."
  print_info "Use 'mariadb chess -e <QUERY>' to run manual queries" 
  print_info "Or use 'mariadb --table chess <tests/<file>"
  print_info "to run the included test queries"
}
