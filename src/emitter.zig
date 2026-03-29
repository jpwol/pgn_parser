const std = @import("std");
const Writer = std.io.Writer;
const Game = @import("globals.zig").Game;
const h = @import("helpers.zig");

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
        try moves_writer.print("{d},{d},{c},", .{ game_id, m.move_number, m.player });
        try emitEscapedCSV(moves_writer, m.move_text);
        try moves_writer.print("\n", .{});
    }
}
