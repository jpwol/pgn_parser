SELECT AVG(move_count) as avg_moves
FROM (
  SELECT game_id, MAX(move_number) as move_count
  FROM moves
  GROUP BY game_id
) as game_lengths;
