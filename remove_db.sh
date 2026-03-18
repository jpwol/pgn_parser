#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

start=$SECONDS
print_header "remove_db.sh"

print_info "Removing existing database \"chess\" if it exists..."
mariadb -e "DROP DATABASE IF EXISTS chess"

if [[ $? -eq 0 ]]; then
  print_success $((SECONDS-start))
  exit $?
else
  print_error "An error occurred when removing the database."
  exit $?
fi
