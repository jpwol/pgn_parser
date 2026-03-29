SELECT
  SUM(won) as total_won,
  SUM(total_lost_queen) as total_lost_queen,
  SUM(won) * 100.0 / SUM(total_lost_queen) as pct
FROM (
  SELECT
    SUM(CASE WHEN g.result = '1-0' THEN 1 ELSE 0 END) as won,
    COUNT(*) as total_lost_queen
  FROM games g
  WHERE g.id IN (
    SELECT DISTINCT game_id FROM state WHERE player = 'W' AND queens = 0
  )
  UNION ALL
  SELECT
    SUM(CASE WHEN g.result = '0-1' THEN 1 ELSE 0 END),
    COUNT(*)
  FROM games g
  WHERE g.id IN (
    SELECT DISTINCT game_id FROM state WHERE player = 'B' AND queens = 0
  )
) combined;
