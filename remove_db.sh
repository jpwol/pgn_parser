#!/usr/bin/env bash

printf "remove_db.sh\n"
printf "=====================\n\n"

printf "Removing existing database \"chess_db\"...\n"
mariadb -e "DROP DATABASE IF EXISTS chess_db"

if [[ $? -eq 0 ]]; then
  exit $?
else
  printf "An error occurred when removing the database.\n"
  exit $?
fi
