const std = @import("std");
const Writer = std.io.Writer;
const Reader = std.io.Reader;
const Game = @import("globals.zig").Game;
const emitter = @import("emitter.zig");

pub fn printProgressBar(writer: *Writer, current: u32, total: u32, width: u32) !void {
    const percent = (current * 100) / total;
    const filled = (current * width) / total;

    try writer.writeAll("\r[");
    for (0..width) |i| {
        if (i < filled) {
            try writer.writeByte('=');
        } else if (i == filled) {
            try writer.writeByte('>');
        } else {
            try writer.writeByte(' ');
        }
    }
    try writer.print("] {d}% ({d}/{d})", .{ percent, current, total });
}

pub fn getLineCount(reader: *Reader) !u32 {
    const s = struct {
        var line_count: u32 = 0;
    };
    while (try reader.takeDelimiter('\n')) |line| {
        _ = line;
        s.line_count += 1;
    }
    return s.line_count;
}

pub fn getOrInsertPlayer(players: *std.StringHashMap(u32), name: []const u8, writer: *Writer) !u32 {
    const s = struct {
        var next_id: u32 = 0;
    };

    if (players.get(name)) |id| return id;
    s.next_id += 1;
    try players.put(name, s.next_id);
    try writer.print("{d},\"", .{s.next_id});
    try writer.writeAll(name);
    try writer.writeAll("\"\n");

    return s.next_id;
}

pub fn isMoveNumber(token: []const u8) bool {
    var isNumber: bool = true;
    for (token) |c| {
        if (!std.ascii.isDigit(c)) {
            isNumber = false;
        }
    }
    return isNumber;
}

pub fn extractHeader(line: []const u8, alloc: std.mem.Allocator) []const u8 {
    const start = std.mem.indexOf(u8, line, "\"") orelse return "";
    const end = std.mem.indexOf(u8, line[start + 1 ..], "\"") orelse return "";
    const s = line[start + 1 .. start + 1 + end];
    return alloc.dupe(u8, s) catch "";
}

pub fn stripCommentsAndVariations(line: []const u8, out: *[1024]u8, depth_curly: *u8, depth_paren: *u8, depth_square: *u8) usize {
    // static tracking of tokens
    var len: usize = 0;

    for (line) |c| {
        switch (c) {
            '{' => depth_curly.* += 1,
            '}' => if (depth_curly.* > 0) {
                depth_curly.* -= 1;
            },
            '(' => depth_paren.* += 1,
            ')' => if (depth_paren.* > 0) {
                depth_paren.* -= 1;
            },
            '[' => depth_square.* += 1,
            ']' => if (depth_square.* > 0) {
                depth_square.* -= 1;
            },
            else => if (depth_curly.* == 0 and depth_paren.* == 0 and depth_square.* == 0) {
                if (len < out.len) {
                    out[len] = c;
                    len += 1;
                }
            },
        }
    }
    return len;
}

pub fn parseMoveNumber(token: []const u8) u32 {
    var end = token.len;
    while (end > 0 and token[end - 1] == '.') {
        end -= 1;
    }
    if (end == 0) return 0;
    return std.fmt.parseInt(u32, token[0..end], 10) catch 0;
}

pub fn parseCapturedPiece(token: []const u8) ?u8 {
    for (token, 0..) |c, i| {
        if (c == 'x' and i + 1 < token.len) {
            const next = token[i + 1];
            if (std.ascii.isUpper(next)) return next;
        }
    }
    return null;
}

pub fn isGameValid(g: *Game) bool {
    if (g.white.len == 0 or g.black.len == 0) return false;

    for (1..g.move_count) |i| {
        const a = g.moves[i].move_number;
        const b = g.moves[i - 1].move_number;
        const diff = if (a > b) a - b else b - a;
        if (diff > 2) return false;
    }
    // if (g.move_count >= 10) {
    //     const last_move_number = g.moves[g.move_count - 1].move_number;
    //     if (last_move_number < g.move_count / 3) return false;
    // }
    return true;
}
