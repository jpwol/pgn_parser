#!/usr/bin/env bash

general_error () {
  printf "Please run \"pgn_parser\" with a valid .pgn file before running this script.\n"
};

printf "generate_loader.sh\n"
printf "=====================\n\n"

CURRENT_DIR=$(pwd)
EMIT_DIR="$CURRENT_DIR/emit"
OUTPUT_FILE="load.sql"

printf "Locating CSV output directory...\n"
if [[ ! -d "$EMIT_DIR" ]]; then
  printf "error: could not find directory \"emit\"\n"
  general_error
  exit 1
else
  printf "Located CSV output directory: %s\n" $EMIT_DIR
fi

printf "\nGathering CSV files...\n"
CSV_FILES=("games.csv" "players.csv" "moves.csv")

for i in "${CSV_FILES[@]}"; do
  if [[ ! -f "$EMIT_DIR/$i" ]]; then
    printf "Could not locate file %s.\n" $i
    general_error
    exit 1
  else
    printf "Located %s in %s\n" "$i" "$EMIT_DIR"
    # printf "Copying CSV file %s to \"/tmp\"\n" "$i"
    # cp "$EMIT_DIR/$i" "/tmp"

    if [[ ! -f "/tmp/$i" ]]; then
      printf "Copy failed. Aborting.\n"
      exit 1
    fi
  fi
done


printf "\nEmitting SQL to %s\n" "$CURRENT_DIR/$OUTPUT_FILE"

SQL_STRING="SET NAMES latin1;
USE chess;

SET foreign_key_checks = 0;
ALTER TABLE players DISABLE KEYS;
ALTER TABLE games DISABLE KEYS;
ALTER TABLE moves DISABLE KEYS;

LOAD DATA LOCAL INFILE '$EMIT_DIR/players.csv' 
    IGNORE INTO TABLE players
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '\"'
    LINES TERMINATED BY '\\n'
    (id, name);

LOAD DATA LOCAL INFILE '$EMIT_DIR/games.csv'
    IGNORE INTO TABLE games
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '\"'
    LINES TERMINATED BY '\\n'
    (id, white_player_id, black_player_id, result);

LOAD DATA LOCAL INFILE '$EMIT_DIR/moves.csv'
    IGNORE INTO TABLE moves
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '\"'
    LINES TERMINATED BY '\\n'
    (game_id, move_number, player, move_text, is_capture, is_castle, captured_piece);

ALTER TABLE moves ENABLE KEYS;
ALTER TABLE games ENABLE KEYS;
ALTER TABLE players ENABLE KEYS;
SET foreign_key_checks = 1;
"

echo "$SQL_STRING" > $OUTPUT_FILE
