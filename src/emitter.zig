const std = @import("std");
const Writer = std.io.Writer;
const Game = @import("globals.zig").Game;
const h = @import("helpers.zig");

pub fn emitEscapedSQL(writer: *Writer, s: []const u8) !void {
    var start: usize = 0;
    for (s, 0..) |c, i| {
        if (c == '\'') {
            try writer.writeAll(s[start..i]);
            try writer.writeAll("''");
            start = i + 1;
        }
    }

    try writer.writeAll(s[start..]);
}

pub fn emitEscapedCSV(writer: *Writer, s: []const u8) !void {
    const needs_quoting = std.mem.indexOfAny(u8, s, ",\"\n") != null;
    if (needs_quoting) try writer.writeByte('"');
    var start: usize = 0;
    for (s, 0..) |c, i| {
        if (c == '"') {
            try writer.writeAll(s[start..i]);
            try writer.writeAll("\"\"");
            start = i + 1;
        }
    }
    try writer.writeAll(s[start..]);
    if (needs_quoting) try writer.writeByte('"');
}

pub fn emitGameCSV(g: *Game, game_id: u32, players: *std.StringHashMap(u32), players_writer: *Writer, games_writer: *Writer, moves_writer: *Writer) !void {
    const white_id = try h.getOrInsertPlayer(players, g.white, players_writer);
    const black_id = try h.getOrInsertPlayer(players, g.black, players_writer);

    try games_writer.print("{d},{d},{d},", .{ game_id, white_id, black_id });
    try emitEscapedCSV(games_writer, g.result);
    try games_writer.writeAll("\n");

    for (0..g.move_count) |i| {
        const m = g.moves[i];
        const is_capture: u1 = if (m.is_capture) 1 else 0;
        const is_castle: u1 = if (m.is_castle) 1 else 0;
        try moves_writer.print("{d},{d},{c},", .{ game_id, m.move_number, m.player });
        try emitEscapedCSV(moves_writer, m.move_text);
        if (m.captured_piece) |cp| {
            try moves_writer.print(",{d},{d},{c}\n", .{ is_capture, is_castle, cp});
        } else {
            try moves_writer.print(",{d},{d},\n", .{ is_capture, is_castle });
        }
    }
}

pub fn emitGameSQL(g: *Game, game_id: u32, writer: *Writer) !void {
    // players insert
    try writer.writeAll("INSERT IGNORE INTO players(name) VALUES('");
    try emitEscapedSQL(writer, g.white);
    try writer.writeAll("');\n");

    try writer.writeAll("INSERT IGNORE INTO players(name) VALUES('");
    try emitEscapedSQL(writer, g.black);
    try writer.writeAll("');\n");

    // games insert
    try writer.writeAll("INSERT INTO games(id, white_player_id, black_player_id, result) VALUES (");
    try writer.print("{d}, (SELECT id FROM players WHERE name='", .{game_id});
    try emitEscapedSQL(writer, g.white);
    try writer.writeAll("'), (SELECT id FROM players WHERE name='");
    try emitEscapedSQL(writer, g.black);
    try writer.writeAll("'), '");
    try emitEscapedSQL(writer, g.result);
    try writer.writeAll("');\n");

    // Moves insertion
    try writer.writeAll("INSERT INTO moves (game_id, move_number, player, move_text, is_capture, is_castle, captured_piece) VALUES\n");
    for (0..g.move_count) |i| {
        const m = g.moves[i];
        const is_capture: u1 = if (m.is_capture) 1 else 0;
        const is_castle: u1 = if (m.is_castle) 1 else 0;
        const sep = if (i == g.move_count - 1) ";\n" else ",\n";

        try writer.print("({d},{d},'{c}','", .{ game_id, m.move_number, m.player });
        try emitEscapedSQL(writer, m.move_text);
        if (m.captured_piece) |cp| {
            try writer.print("',{d},{d},'{c}'){s}", .{ is_capture, is_castle, cp, sep });
        } else {
            try writer.print("',{d},{d},NULL){s}", .{ is_capture, is_castle, sep });
        }
    }
}
