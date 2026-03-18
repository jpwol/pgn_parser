SELECT 
  COUNT(*) as b4_games,
  (COUNT(*) * 100 / (SELECT COUNT(*) FROM games)) as percentage
FROM games g
JOIN moves m ON g.id = m.game_id
WHERE m.move_number = 1 AND
      m.player = 'W' AND
      m.move_text = 'b4'
