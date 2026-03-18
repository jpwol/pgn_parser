#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

start=$SECONDS

print_header "init_db.sh"

INSERT_FILE="./load.sql"

print_info "Initializing database schema..."
mariadb < ./schema.sql

print_info "Loading CSV files into database..."
if [[ -f $INSERT_FILE ]]; then
  mariadb < $INSERT_FILE

  print_success $((SECONDS-start))
  exit $?
else
  print_error "File not found"
  exit 1
fi
