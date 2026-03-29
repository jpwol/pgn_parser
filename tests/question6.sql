SELECT
  COUNT(*) as total_games,
  SUM(CASE
    WHEN bishop_side.player = 'W' AND g.result = '1-0' THEN 1
    WHEN bishop_side.player = 'B' AND g.result = '0-1' THEN 1
    ELSE 0
  END) as bishop_side_won,
  SUM(CASE
    WHEN bishop_side.player = 'W' AND g.result = '1-0' THEN 1
    WHEN bishop_side.player = 'B' AND g.result = '0-1' THEN 1
    ELSE 0
  END) * 100.0 / COUNT(*) as pct_bishop_won
FROM games g
JOIN (
  -- find the move where the endgame position is reached
  SELECT DISTINCT s1.game_id, s1.player as player
  FROM state s1
  JOIN state s2 ON s1.game_id = s2.game_id
    AND s1.move_number = s2.move_number
    AND s1.player != s2.player
  WHERE
    -- one side has 2 bishops, no rooks, no knights, no queens
    s1.bishops = 2 AND s1.rooks = 0 AND s1.knights = 0 AND s1.queens = 0
    -- other side has 1 rook, no bishops, no knights, no queens
    AND s2.bishops = 0 AND s2.rooks = 1 AND s2.knights = 0 AND s2.queens = 0
) bishop_side ON g.id = bishop_side.game_id;
