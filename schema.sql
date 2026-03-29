CREATE DATABASE IF NOT EXISTS chess;
USE chess;
CREATE TABLE IF NOT EXISTS players(
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL, 
  UNIQUE(name)
);

CREATE TABLE IF NOT EXISTS games(
  id INT PRIMARY KEY,
  white_player_id INT NOT NULL,
  black_player_id INT NOT NULL,
  result VARCHAR(7),
  FOREIGN KEY(white_player_id) REFERENCES players(id),
  FOREIGN KEY(black_player_id) REFERENCES players(id)
);

CREATE TABLE IF NOT EXISTS moves(
  game_id INT NOT NULL,
  move_number INT NOT NULL,
  player ENUM(
    'W',
    'B'
  ) NOT NULL,
  move_text VARCHAR(10) NOT NULL,

  PRIMARY KEY (game_id, move_number, player),
  FOREIGN KEY(game_id) REFERENCES games(id)
);

CREATE TABLE IF NOT EXISTS state(
  game_id     INT NOT NULL,
  move_number INT NOT NULL,
  player      ENUM('W','B') NOT NULL,
  pawns       TINYINT UNSIGNED NOT NULL DEFAULT 8,
  knights     TINYINT UNSIGNED NOT NULL DEFAULT 2,
  bishops     TINYINT UNSIGNED NOT NULL DEFAULT 2,
  rooks       TINYINT UNSIGNED NOT NULL DEFAULT 2,
  queens      TINYINT UNSIGNED NOT NULL DEFAULT 1,

  PRIMARY KEY (game_id, move_number, player),
  FOREIGN KEY (game_id, move_number, player) REFERENCES moves(game_id, move_number, player)
);

CREATE INDEX IF NOT EXISTS idx_games_white_player ON games(white_player_id);
CREATE INDEX IF NOT EXISTS idx_games_black_player ON games(black_player_id);

CREATE INDEX IF NOT EXISTS idx_moves_game ON moves(game_id);
CREATE INDEX IF NOT EXISTS idx_moves_move_number ON moves(move_number);
CREATE INDEX IF NOT EXISTS idx_moves_move_text ON moves(move_text);
CREATE INDEX IF NOT EXISTS idx_opening_move ON moves(move_number, player, move_text);
