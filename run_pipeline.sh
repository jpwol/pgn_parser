#!/usr/bin/env bash

INFILE="${1:-twic210-874.pgn}"
OUTFILE="output.sql"

clear
printf "Building binary...\n"
zig build || { printf "Build failed\n"; exit 1; }

printf "Running parser...\n"
./bin/pgn_parser $INFILE > $OUTFILE

printf "Clearing database...\n"
./remove_db.sh

printf "Initialize fresh database and injecting SQL...\n"
./init_db.sh

ret=$?

if [[ $ret -eq 0 ]]; then
printf "Done!\n"
else
  printf "An error occured...\n"
fi
