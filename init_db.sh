#!/usr/bin/env bash

INSERT_FILE="./output.sql"

mariadb < ./schema.sql

if [[ -f $INSERT_FILE ]]; then
  mariadb chess_db < $INSERT_FILE
else
  echo "error: file not found"
  exit 1
fi
