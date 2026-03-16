#!/usr/bin/env bash

INFILE="twic210-874.pgn"
OUTFILE="output.sql"

printf "\u001b[2J"
printf "\u001b[HBuilding binary...\n"
zig build
printf "Running parser...\n"
./bin/pgn_parser $INFILE > $OUTFILE
printf "Clearing database...\n"
./remove_db.sh
printf "Initialize fresh database and injecting SQL...\n"
./init_db.sh
printf "Done!"
