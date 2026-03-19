#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

start=$SECONDS
print_header "remove_db.sh"

print_info "Removing existing database \"chess\" if it exists..."
mariadb $MARIADB_CONN -e "DROP DATABASE IF EXISTS chess"
ret=$?

if [[ $ret -eq 0 ]]; then
  print_success $((SECONDS-start))
  exit 0
else
  print_error "An error occurred when removing the database."
  exit 1
fi
