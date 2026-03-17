#!/usr/bin/env bash

clear

dir=$(pwd)

printf "run_pipeline.sh\n"
printf "=====================\n\n"

INFILE="${1:-twic210-874.pgn}"

printf "Building binary...\n"
zig build || { 
  printf "Build failed\n"; 
  printf "Aborting...\n"
  exit 1; 
}

printf "Executing %s with file \"%s\"\n\n" "$dir/bin/pgn_parser" "$INFILE"
printf "pgn_parser\n"
printf "=====================\n\n"
./bin/pgn_parser "$INFILE"

printf "\nGenerating loader...\n\n"
./generate_loader.sh
ret=$?
if [[ $ret -eq 0 ]]; then
  printf "Done!\n"
else
  printf "An error occured when generating loader\n"
  printf "Aborting...\n"
  exit 1; 
fi

printf "Clearing database...\n\n"
./remove_db.sh

ret=$?
if [[ $ret -eq 0 ]]; then
  printf "Done!\n"
else
  printf "An error occured when removing old database\n"
  printf "Aborting...\n"
  exit 1; 
fi

printf "initializing fresh database and loading CSVs...\n\n"
./init_db.sh

ret=$?
if [[ $ret -eq 0 ]]; then
printf "Done!\n"
else
  printf "An error occured when initializing the database\n"
  printf "Aborting...\n"
  exit 1; 
fi
