#!/usr/bin/env bash

printf "init_db.sh\n"
printf "=====================\n\n"

INSERT_FILE="./load.sql"

printf "Initializing database schema...\n"
mariadb < ./schema.sql

printf "Loading CSV files into database...\n"
if [[ -f $INSERT_FILE ]]; then
  mariadb --local-infile=1 < $INSERT_FILE
  exit $?
else
  echo "error: file not found"
  exit 1
fi
