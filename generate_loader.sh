#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

start=$SECONDS

general_error () {
  printf "Please run \"pgn_parser\" with a valid .pgn file before running this script.\n"
};

print_header "generate_loader.sh"

CURRENT_DIR=$(pwd)
EMIT_DIR="$CURRENT_DIR/emit"
OUTPUT_FILE="load.sql"

print_info "Locating CSV output directory..."
if [[ ! -d "$EMIT_DIR" ]]; then
  print_error "Could not find directory \"emit\"\n"
  print_error $(general_error)
  exit 1
else
  print_info "Located CSV output directory: ${EMIT_DIR}"
fi

print_info "Gathering CSV files..."
CSV_FILES=("games.csv" "players.csv" "moves.csv")

for i in "${CSV_FILES[@]}"; do
  if [[ ! -f "$EMIT_DIR/$i" ]]; then
    print_error "Could not locate file ${i}"
    print_error $(general_error)
    exit 1
  else
    print_info "Located ${i} in ${EMIT_DIR}"
  fi
done


print_info "Emitting SQL to ${CURRENT_DIR}/${OUTPUT_FILE}"

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
    (game_id, move_number, player, move_text);

LOAD DATA LOCAL INFILE '$EMIT_DIR/state.csv'
    IGNORE INTO TABLE state
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '\"'
    LINES TERMINATED BY '\\n'
    (game_id, move_number, player, pawns, knights, bishops, rooks, queens);

ALTER TABLE moves ENABLE KEYS;
ALTER TABLE games ENABLE KEYS;
ALTER TABLE players ENABLE KEYS;
SET foreign_key_checks = 1;
"

echo "$SQL_STRING" > $OUTPUT_FILE

print_success $((SECONDS-start))
