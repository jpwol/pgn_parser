SELECT COUNT(DISTINCT game_id)
FROM moves
WHERE move_text = 'O-O'
AND move_number <= 20;
