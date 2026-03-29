pub const Move = struct {
    move_number: u32,
    player: u8,
    move_text: []const u8,
};

pub const Game = struct {
    white: []const u8,
    black: []const u8,
    result: []const u8,
    moves: [1024]Move,
    move_count: usize,
};

pub const State = struct {
    white_pawn: u64 = 0x000000000000FF00,
    white_knight: u64 = 0x0000000000000042,
    white_bishop: u64 = 0x0000000000000024,
    white_rook: u64 = 0x0000000000000081,
    white_queen: u64 = 0x0000000000000010,
    white_king: u64 = 0x0000000000000008,
    black_pawn: u64 = 0x00FF000000000000,
    black_knight: u64 = 0x4200000000000000,
    black_bishop: u64 = 0x2400000000000000,
    black_rook: u64 = 0x8100000000000000,
    black_queen: u64 = 0x1000000000000000,
    black_king: u64 = 0x0800000000000000,
};

pub const Piece = enum {
    PAWN,
    KNIGHT,
    BISHOP,
    ROOK,
    QUEEN,
    KING,
};
