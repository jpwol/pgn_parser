pub const Move = struct {
    // ply: u32,
    move_number: u32,
    player: u8,
    move_text: []const u8,
    is_capture: bool,
    is_castle: bool,
    captured_piece: ?u8,
};

pub const Game = struct {
    white: []const u8,
    black: []const u8,
    result: []const u8,
    moves: [1024]Move,
    move_count: usize,
};
