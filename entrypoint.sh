#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

COUNT=$(mariadb -h db -u root -proot chess -e "SELECT COUNT(*) FROM games;" 2>/dev/null | tail -1)
if [[ "$COUNT" -gt 0 ]]; then
  print_info "Database already populated with $COUNT games, skipping pipeline..."
else
  ./run_pipeline.sh /app/input/${PGN_FILE}
fi
