#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

start=$SECONDS

print_header "init_db.sh"

INSERT_FILE="./load.sql"

print_info "Initializing database schema..."
mariadb $MARIADB_CONN < ./schema.sql

print_info "Loading CSV files into database..."
if [[ -f $INSERT_FILE ]]; then
  mariadb $MARIADB_CONN < $INSERT_FILE
  ret=$?
  if [[ $ret -eq 0 ]]; then
    print_success $((SECONDS-start))
    exit 0
  else 
    print_error "MariaDB could not load the CSV files into the database"
    exit 1
  fi

else
  print_error "File not found"
  exit 1
fi
