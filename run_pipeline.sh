#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
start=$SECONDS

dir=$(pwd)

print_header "run_pipeline.sh"

INFILE="${1:-infile.pgn}"

print_info "Building binary"
zig build || { 
  print_error "Build failed. Aborting..."
  exit 1; 
}
print_success $((SECONDS-start))

print_info "Executing ${dir}/bin/pgn_parser with file \"${INFILE}\"" 
parser_start=$SECONDS

print_header "pgn_parser"
./bin/pgn_parser "$INFILE" || {
  print_error "Parsing failed. Aborting..."
  exit 1
}
print_success $((SECONDS-parser_start))

print_info "Generating loader"
./generate_loader.sh
ret=$?
if [[ $ret -ne 0 ]]; then
  print_error "An error occured when generating loader. Aborting..."
  exit 1; 
fi

print_info "Clearing database..."
./remove_db.sh

ret=$?
if [[ $ret -ne 0 ]]; then
  print_error "An error occured when removing old database. Aborting..."
  exit 1; 
fi

print_info "Initializing fresh database and loading CSVs"
./init_db.sh

ret=$?
if [[ $ret -ne 0 ]]; then
  print_error "An error occured when initializing the database. Aborting..."
  exit 1; 
fi

print_pipeline_success $((SECONDS-start))
print_completion
