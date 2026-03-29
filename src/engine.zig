const std = @import("std");
const Writer = std.Io.Writer;
const Globals = @import("globals.zig");

const Game = Globals.Game;
const Move = Globals.Move;
const State = Globals.State;
const Piece = Globals.Piece;

const ParsedMove = struct {
    piece: Piece,
    disambig: ?u8,
    dest: [2]u8,
    is_capture: bool,
    promotion: ?Piece,
};

const piece_lookup: [40]?Piece = blk: {
    var table = [_]?Piece{null} ** 40;
    table['B' - 'A'] = .BISHOP;
    table['K' - 'A'] = .KING;
    table['N' - 'A'] = .KNIGHT;
    table['Q' - 'A'] = .QUEEN;
    table['R' - 'A'] = .ROOK;

    break :blk table;
};

pub const Game_Engine = struct {
    state: State = .{},

    pub fn evaluate(self: *Game_Engine, game: Game, game_id: u32, writer: *Writer) !void {
        for (game.moves[0..game.move_count]) |m| {
            // std.debug.print("raw move bytes: ", .{});
            // for (m.move_text) |b| std.debug.print("{d} ", .{b});
            // std.debug.print("\n", .{});
            const move_text = m.move_text;
            // std.debug.print("{s}\n", .{move_text});
            
            if (move_text.len == 0) continue;
            if (move_text[0] == '-' or move_text[0] == '1' or move_text[0] == '0') continue;
            if (move_text[0] == 'Z') continue;

            if (move_text[0] == 'O') {
                self.handleCastle(move_text, m.player);
            } else {
                const parsed = parseSan(move_text);
                if (!self.applyMove(parsed, m.player)) {
                    self.state = .{};
                    return;
                }
            }
            const state = if (m.player == 'W') self.state.white_pawn else self.state.black_pawn;
            _ = state;
            const pawns = if (m.player == 'W') @popCount(self.state.white_pawn) else @popCount(self.state.black_pawn);
            const knights = if (m.player == 'W') @popCount(self.state.white_knight) else @popCount(self.state.black_knight);
            const bishops = if (m.player == 'W') @popCount(self.state.white_bishop) else @popCount(self.state.black_bishop);
            const rooks = if (m.player == 'W') @popCount(self.state.white_rook) else @popCount(self.state.black_rook);
            const queens = if (m.player == 'W') @popCount(self.state.white_queen) else @popCount(self.state.black_queen);
            try writer.print("{d},{d},{c},{d},{d},{d},{d},{d}\n", .{
                game_id,
                m.move_number,
                m.player,
                pawns,
                knights,
                bishops,
                rooks,
                queens,
            });

            // self.sanityCheck();
            // self.dumpBoardState();
        }
        self.state = .{};
    }

    fn squareToBit(square: []const u8) u6 {
        const file = square[0];
        const rank = square[1];
        if (rank < '1' or rank > '8' or file < 'a' or file > 'h') {
            std.debug.print("BAD SQUARE: file={c}({d}) rank={c}({d})\n", .{file, file, rank, rank});
            return 0;
        }

        return @intCast(((rank - '1') * 8) + ('h' - file));
    }

    fn bitToSquare(bit: u8) [2]u8 {
        const rank_index = bit / 8;
        const rank = '1' + rank_index;

        const file_index = bit % 8;
        const file = 'h' - file_index;

        return .{ file, rank };
    }

    fn setBit(board: *u64, square: []const u8) void {
        board.* |= @as(u64, 1) << squareToBit(square);
    }

    fn clearBit(board: *u64, square: []const u8) void {
        board.* &= ~(@as(u64, 1) << squareToBit(square));
    }

    fn checkBit(board: *u64, square: []const u8) bool {
        return (board.* & @as(u64, 1) << squareToBit(square)) >= 1;
    }

    fn bitFile(bit: u8) u8 {
        return 'h' - (bit % 8);
    }

    fn bitRank(bit: u8) u8 {
        return (bit / 8) + '1';
    }

    pub fn getCurrentBoardState(self: *Game_Engine) u64 {
        const board = self.state.white_pawn | self.state.white_knight | self.state.white_bishop |
            self.state.white_rook | self.state.white_king | self.state.white_queen |
            self.state.black_pawn | self.state.black_knight | self.state.black_bishop |
            self.state.black_rook | self.state.black_king | self.state.black_queen;

        return board;
    }
    fn parseSan(text: []const u8) ParsedMove {
        const move = std.mem.trimRight(u8, text, "+#+");

        var result = ParsedMove{
            .piece = .PAWN,
            .disambig = null,
            .dest = undefined,
            .is_capture = std.mem.indexOf(u8, move, "x") != null,
            .promotion = null,
        };

        var move_trimmed = move;
        if (std.mem.indexOf(u8, move, "=")) |eq| {
            result.promotion = piece_lookup[move[eq + 1] - 'A'].?;
            move_trimmed = move[0..eq];
        } else if (move.len >= 2 and std.ascii.isUpper(move[move.len - 1])) {
            const last = move[move.len - 1];
            if (last == 'Q' or last == 'R' or last == 'B' or last == 'N') {
                result.promotion = piece_lookup[last - 'A'];
                move_trimmed = move[0..move.len - 1];
            }
        }

        result.dest = move_trimmed[move_trimmed.len - 2 ..][0..2].*;

        const prefix = move_trimmed[0 .. move_trimmed.len - 2];

        const stripped = if (result.is_capture) blk: {
            const x = std.mem.indexOf(u8, prefix, "x").?;
            break :blk prefix[0..x];
        } else prefix;

        switch (stripped.len) {
            0 => {},
            1 => {
                if (std.ascii.isUpper(stripped[0])) {
                    result.piece = piece_lookup[stripped[0] - 'A'].?;
                } else {
                    result.disambig = stripped[0];
                }
            },
            2 => {
                result.piece = piece_lookup[stripped[0] - 'A'].?;
                result.disambig = stripped[1];
            },
            else => {},
        }
        return result;
    }

    fn applyMove(self: *Game_Engine, parsed: ParsedMove, player: u8) bool {
        const dest_bit = squareToBit(&parsed.dest);

        if (parsed.is_capture) {
            const all_pieces = self.getCurrentBoardState();
            const dest_empty = all_pieces & (@as(u64, 1) << @intCast(dest_bit)) == 0;

            if (parsed.piece == .PAWN and dest_empty) {
                // en passant: captured pawn is one rank behind the destination
                const ep_bit: u8 = if (player == 'W') dest_bit - 8 else dest_bit + 8;
                const ep_mask = ~(@as(u64, 1) << @intCast(ep_bit));
                if (player == 'W') {
                    self.state.black_pawn &= ep_mask;
                } else {
                    self.state.white_pawn &= ep_mask;
                }
            } else {
                self.clearCapturedPiece(parsed.dest, player);
            }
        }

        const from_bit = self.findFromSquare(parsed.piece, dest_bit, parsed.disambig, player) orelse return false;
        self.movePiece(parsed.piece, from_bit, dest_bit, player);

        if (parsed.promotion) |promo| {
            self.promotePawn(dest_bit, promo, player);
        }

        return true;
    }

    fn movePiece(self: *Game_Engine, piece: Piece, from_bit: u8, dest_bit: u8, player: u8) void {
        const mask_clear = ~(@as(u64, 1) << @intCast(from_bit));
        const mask_set = @as(u64, 1) << @intCast(dest_bit);
        switch (piece) {
            .PAWN => if (player == 'W') {
                self.state.white_pawn &= mask_clear;
                self.state.white_pawn |= mask_set;
            } else {
                self.state.black_pawn &= mask_clear;
                self.state.black_pawn |= mask_set;
            },
            .KNIGHT => if (player == 'W') {
                self.state.white_knight &= mask_clear;
                self.state.white_knight |= mask_set;
            } else {
                self.state.black_knight &= mask_clear;
                self.state.black_knight |= mask_set;
            },
            .BISHOP => if (player == 'W') {
                self.state.white_bishop &= mask_clear;
                self.state.white_bishop |= mask_set;
            } else {
                self.state.black_bishop &= mask_clear;
                self.state.black_bishop |= mask_set;
            },
            .ROOK => if (player == 'W') {
                self.state.white_rook &= mask_clear;
                self.state.white_rook |= mask_set;
            } else {
                self.state.black_rook &= mask_clear;
                self.state.black_rook |= mask_set;
            },
            .QUEEN => if (player == 'W') {
                self.state.white_queen &= mask_clear;
                self.state.white_queen |= mask_set;
            } else {
                self.state.black_queen &= mask_clear;
                self.state.black_queen |= mask_set;
            },
            .KING => if (player == 'W') {
                self.state.white_king &= mask_clear;
                self.state.white_king |= mask_set;
            } else {
                self.state.black_king &= mask_clear;
                self.state.black_king |= mask_set;
            },
        }
    }

    fn promotePawn(self: *Game_Engine, dest_bit: u8, promo: Piece, player: u8) void {
        const mask_clear = ~(@as(u64, 1) << @intCast(dest_bit));
        const mask_set = @as(u64, 1) << @intCast(dest_bit);
        if (player == 'W') {
            self.state.white_pawn &= mask_clear;
            switch (promo) {
                .QUEEN => self.state.white_queen |= mask_set,
                .ROOK => self.state.white_rook |= mask_set,
                .BISHOP => self.state.white_bishop |= mask_set,
                .KNIGHT => self.state.white_knight |= mask_set,
                else => unreachable,
            }
        } else {
            self.state.black_pawn &= mask_clear;
            switch (promo) {
                .QUEEN => self.state.black_queen |= mask_set,
                .ROOK => self.state.black_rook |= mask_set,
                .BISHOP => self.state.black_bishop |= mask_set,
                .KNIGHT => self.state.black_knight |= mask_set,
                else => unreachable,
            }
        }
    }

    fn clearCapturedPiece(self: *Game_Engine, dest: [2]u8, player: u8) void {
        const bit = @as(u64, 1) << squareToBit(&dest);

        if (player == 'W') {
            if (self.state.black_pawn & bit != 0) {
                self.state.black_pawn &= ~bit;
                return;
            }
            if (self.state.black_knight & bit != 0) {
                self.state.black_knight &= ~bit;
                return;
            }
            if (self.state.black_bishop & bit != 0) {
                self.state.black_bishop &= ~bit;
                return;
            }
            if (self.state.black_rook & bit != 0) {
                self.state.black_rook &= ~bit;
                return;
            }
            if (self.state.black_queen & bit != 0) {
                self.state.black_queen &= ~bit;
                return;
            }
        } else {
            if (self.state.white_pawn & bit != 0) {
                self.state.white_pawn &= ~bit;
                return;
            }
            if (self.state.white_knight & bit != 0) {
                self.state.white_knight &= ~bit;
                return;
            }
            if (self.state.white_bishop & bit != 0) {
                self.state.white_bishop &= ~bit;
                return;
            }
            if (self.state.white_rook & bit != 0) {
                self.state.white_rook &= ~bit;
                return;
            }
            if (self.state.white_queen & bit != 0) {
                self.state.white_queen &= ~bit;
                return;
            }
        }
    }

    fn findFromSquare(self: *Game_Engine, piece: Piece, dest_bit: u8, disambig: ?u8, player: u8) ?u8 {
        switch (piece) {
            .PAWN => {
                if (player == 'W') {
                    const board = self.state.white_pawn;
                    if (disambig) |d| {
                        // d is source file letter e.g. 'c', convert to bit-file index
                        const src_file: u8 = 'h' - d;
                        // dest_bit - 8 puts us on the same file as dest but one rank back,
                        // then we mask off the file bits and add our source file
                        const src_bit: u8 = (dest_bit - 8) & ~@as(u8, 7) | src_file;
                        std.debug.assert(board & (@as(u64, 1) << @intCast(src_bit)) != 0);
                        return src_bit;
                    } else {
                        if (dest_bit >= 8) {
                            const single: u8 = dest_bit - 8;
                            if (board & (@as(u64, 1) << @intCast(single)) != 0) return single;
                        }
                        return dest_bit - 16;
                    }
                } else {
                    const board = self.state.black_pawn;
                    if (disambig) |d| {
                        const src_file: u8 = 'h' - d;
                        const src_bit: u8 = (dest_bit + 8) & ~@as(u8, 7) | src_file;
                        std.debug.assert(board & (@as(u64, 1) << @intCast(src_bit)) != 0);
                        return src_bit;
                    } else {
                        if (dest_bit + 8 < 64) {
                            const single: u8 = dest_bit + 8;
                            if (board & (@as(u64, 1) << @intCast(single)) != 0) return single;
                        }
                        return dest_bit + 16;
                    }
                }
            },
            .KNIGHT => {
                const board = if (player == 'W') self.state.white_knight else self.state.black_knight;
                const knight_offsets = [_]u8{ 6, 10, 15, 17 };

                for (knight_offsets) |offset| {
                    if (dest_bit + offset < 64) {
                        const candidate: u8 = dest_bit + offset;
                        const file_diff = @abs(@as(i8, @intCast(candidate % 8)) - @as(i8, @intCast(dest_bit % 8)));
                        const rank_diff = @abs(@as(i8, @intCast(candidate / 8)) - @as(i8, @intCast(dest_bit / 8)));
                        const valid = (file_diff == 1 and rank_diff == 2) or (file_diff == 2 and rank_diff == 1);
                        if (valid and board & (@as(u64, 1) << @intCast(candidate)) != 0) {
                            if (disambig == null or disambig.? == bitFile(candidate) or disambig.? == bitRank(candidate)) {
                                return candidate;
                            }
                        }
                    }
                    if (dest_bit >= offset) {
                        const candidate: u8 = dest_bit - offset;
                        const file_diff = @abs(@as(i8, @intCast(candidate % 8)) - @as(i8, @intCast(dest_bit % 8)));
                        const rank_diff = @abs(@as(i8, @intCast(candidate / 8)) - @as(i8, @intCast(dest_bit / 8)));
                        const valid = (file_diff == 1 and rank_diff == 2) or (file_diff == 2 and rank_diff == 1);
                        if (valid and board & (@as(u64, 1) << @intCast(candidate)) != 0) {
                            if (disambig == null or disambig.? == bitFile(candidate) or disambig.? == bitRank(candidate)) {
                                return candidate;
                            }
                        }
                    }
                }
            },
            .BISHOP => {
                const board = if (player == 'W') self.state.white_bishop else self.state.black_bishop;
                const bishop_dirs = [_]i8{ 9, -9, 7, -7 };

                const all_pieces = self.getCurrentBoardState();
                for (bishop_dirs) |dir| {
                    var current: i8 = @intCast(dest_bit);
                    while (true) {
                        const prev_file = @mod(current, 8);
                        current += dir;
                        if (current < 0 or current >= 64) break;
                        const new_file = @mod(current, 8);

                        // if file changes by more than 1 then wrap happened -> NOT GOOD!
                        if (@abs(new_file - prev_file) != 1) break;

                        const bit: u6 = @intCast(current);


                        if (board & (@as(u64, 1) << bit) != 0) {
                            if (disambig == null or disambig.? == bitFile(@intCast(bit)) or disambig.? == bitRank(@intCast(bit))) {
                                return @intCast(bit);
                            }
                            break;
                        }

                        if (all_pieces & (@as(u64, 1) << @intCast(bit)) != 0)  break; 
                    }
                }
            },
            .ROOK => {
                const board = if (player == 'W') self.state.white_rook else self.state.black_rook;
                const rook_dirs = [_]i8{ 1, -1, 8, -8 };

                const all_pieces = self.getCurrentBoardState();
                for (rook_dirs) |dir| {
                    var current: i8 = @intCast(dest_bit);
                    while (true) {
                        const prev_rank = @divFloor(current, 8);
                        current += dir;
                        if (current < 0 or current >= 64) break;
                        const new_rank = @divFloor(current, 8);
                        // for horizontal movement, stop if we crossed a rank
                        if ((dir == @as(i8, 1) or dir == @as(i8, -1)) and new_rank != prev_rank) break;
                        const bit: u8 = @intCast(current);


                        if (board & (@as(u64, 1) << @intCast(bit)) != 0) {
                            if (disambig == null or disambig.? == bitFile(@intCast(bit)) or disambig.? == bitRank(@intCast(bit))) {
                                return @intCast(bit);
                            }
                            break;
                        }
                        if (all_pieces & (@as(u64, 1) << @intCast(bit)) != 0) break;
                    }
                }
            },
            .QUEEN => {
                const board = if (player == 'W') self.state.white_queen else self.state.black_queen;
                const queen_dirs = [_]i8{ 1, -1, 8, -8, 9, -9, 7, -7 };

                const all_pieces = self.getCurrentBoardState();
                for (queen_dirs) |dir| {
                    var current: i8 = @intCast(dest_bit);
                    while (true) {
                        const prev = @mod(current, 8);
                        const prev_rank = @divFloor(current, 8);
                        current += dir;
                        if (current < 0 or current >= 64) break;
                        const new = @mod(current, 8);
                        const new_rank = @divFloor(current, 8);
                        // horizontal wrap check (rook-like dirs)
                        if ((dir == 1 or dir == -1) and new_rank != prev_rank) break;
                        // diagonal wrap check (bishop-like dirs)
                        if ((dir == 9 or dir == -9 or dir == 7 or dir == -7) and @abs(new - prev) != 1) break;
                        const bit: u8 = @intCast(current);


                        if (board & (@as(u64, 1) << @intCast(bit)) != 0) {
                            if (disambig == null or disambig.? == bitFile(@intCast(bit)) or disambig.? == bitRank(@intCast(bit))) {
                                return @intCast(bit);
                            }
                            break;
                        }
                        if (all_pieces & (@as(u64, 1) << @intCast(bit)) != 0) break;
                    }
                }
            },
            .KING => {
                const board = if (player == 'W') self.state.white_king else self.state.black_king;
                const king_dirs = [_]i8{ 1, -1, 8, -8, 9, -9, 7, -7 };
                for (king_dirs) |dir| {
                    const prev = dest_bit % 8;
                    const prev_rank = @divFloor(@as(i8, @intCast(dest_bit)), 8);
                    const next: i8 = @as(i8, @intCast(dest_bit)) + dir;
                    if (next < 0 or next >= 64) continue;
                    const new: i8 = @mod(next, 8);
                    const new_rank = @divFloor(next, 8);
                    if ((dir == 1 or dir == -1) and new_rank != prev_rank) continue;
                    if ((dir == 9 or dir == -9 or dir == 7 or dir == -7) and @abs(new - @as(i8, @intCast(prev))) != 1) continue;
                    const bit: u9 = @intCast(next);
                    if (board & (@as(u64, 1) << @intCast(bit)) != 0) return @intCast(bit);
                }
            },
        }
        return null;
    }

    fn handleCastle(self: *Game_Engine, text: []const u8, player: u8) void {
        const queenside = std.mem.startsWith(u8, text, "O-O-O");
        if (player == 'W') {
            if (queenside) {
                // king e1->c1, rook a1->d1
                self.movePiece(.KING, squareToBit("e1"), squareToBit("c1"), player);
                self.movePiece(.ROOK, squareToBit("a1"), squareToBit("d1"), player);
            } else {
                // king e1->g1, rook h1->f1
                self.movePiece(.KING, squareToBit("e1"), squareToBit("g1"), player);
                self.movePiece(.ROOK, squareToBit("h1"), squareToBit("f1"), player);
            }
        } else {
            if (queenside) {
                self.movePiece(.KING, squareToBit("e8"), squareToBit("c8"), player);
                self.movePiece(.ROOK, squareToBit("a8"), squareToBit("d8"), player);
            } else {
                self.movePiece(.KING, squareToBit("e8"), squareToBit("g8"), player);
                self.movePiece(.ROOK, squareToBit("h8"), squareToBit("f8"), player);
            }
        }
    }

    fn dumpBoardState(self: *Game_Engine) void {
        var board: [8][8]u8 = undefined;

        // Fill with '.'
        for (&board) |*rank| {
            for (rank) |*cell| {
                cell.* = '.';
            }
        }

        // Place pieces
        placeBitboard(&board, self.state.white_pawn,   'P');
        placeBitboard(&board, self.state.white_knight, 'N');
        placeBitboard(&board, self.state.white_bishop, 'B');
        placeBitboard(&board, self.state.white_rook,   'R');
        placeBitboard(&board, self.state.white_queen,  'Q');
        placeBitboard(&board, self.state.white_king,    'K');

        placeBitboard(&board, self.state.black_pawn,   'p');
        placeBitboard(&board, self.state.black_knight, 'n');
        placeBitboard(&board, self.state.black_bishop, 'b');
        placeBitboard(&board, self.state.black_rook,   'r');
        placeBitboard(&board, self.state.black_queen,  'q');
        placeBitboard(&board, self.state.black_king,    'k');

    // Print (top = rank 8)
    var r: i32 = 7;
    while (r >= 0) : (r -= 1) {
        std.debug.print("{} ", .{r + 1});
        std.debug.print("{s}\n", .{board[@intCast(r)][0..]});
    }

    std.debug.print("  hgfedcba\n", .{});
    }
    fn placeBitboard(board: *[8][8]u8, bb: u64, piece: u8) void {
        var bits = bb;

        while (bits != 0) {
            const sq: u6 = @intCast(@ctz(bits)); // index of least significant bit

            const rank = sq / 8;
            const file = sq % 8;

            board[rank][file] = piece;

            bits &= bits - 1; // clear lowest set bit
        }
    }
    fn sanityCheck(self: *Game_Engine) void {
        const overlap =
    (self.state.white_pawn & self.state.black_pawn) |
    (self.state.white_knight & self.state.black_knight) |
    (self.state.white_bishop & self.state.black_bishop);

        std.debug.assert(overlap == 0);
    }
};
