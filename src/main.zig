const std = @import("std");
const allocator = std.heap.page_allocator;
const globals = @import("globals.zig");
const Game = globals.Game;
const Move = globals.Move;
const Writer = std.io.Writer;

pub fn main() !void {
    const stdout = std.fs.File.stdout();
    const stderr = std.fs.File.stderr();
    var buf: [65536]u8 = undefined;

    var ww = stdout.writer(&.{});
    var ew = stderr.writer(&buf);
    const writer = &ww.interface;
    const err_writer = &ew.interface;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        try err_writer.print("usage: parse <file>\n", .{});
        return;
    }

    const file_string = args[1];
    const pgn_file = std.fs.cwd().openFile(file_string, .{}) catch |err| {
        try err_writer.print("error: couldn't open file {s}: {}\n", .{ file_string, err });
        return;
    };
    defer pgn_file.close();
    var line_buf: [1024]u8 = undefined;
    var rw = pgn_file.reader(&line_buf);
    const reader = &rw.interface;

    var g: Game = std.mem.zeroes(Game);
    // var ply: u32 = 0;
    var game_id: u32 = 1;
    var move_number: u32 = 0;
    var next_player: u8 = 'W';

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var depth_curly: u8 = 0;
    var depth_paren: u8 = 0;

    const ParseState = enum { waiting, in_headers, in_moves };
    var state: ParseState = .waiting;

    try err_writer.print("starting...\n", .{});

    try writer.writeAll("SET NAMES latin1;\n");
    try writer.writeAll("START TRANSACTION;\n");
    try writer.writeAll("ALTER TABLE players DISABLE KEYS;\n");
    try writer.writeAll("ALTER TABLE games DISABLE KEYS;\n");
    try writer.writeAll("ALTER TABLE moves DISABLE KEYS;\n");
    while (true) {
        const line = try reader.takeDelimiter('\n');
        if (line == null) break;
        const l = line.?;
        const trimmed = std.mem.trim(u8, l, " \t\n\r");

        if (trimmed.len == 0) {
            if (state == .in_moves) {
                if (g.move_count > 0 and g.white.len > 0 and g.black.len > 0) {
                    if (isGameValid(&g)) {
                        try emitGameSQL(&g, game_id, writer);
                        game_id += 1;
                    }

                    g = std.mem.zeroes(Game);
                    _ = arena.reset(.retain_capacity);

                    depth_curly = 0;
                    depth_paren = 0;

                    move_number = 0;
                    next_player = 'W';
                }
                state = .waiting;
            } else if (state == .in_headers) {
                state = .in_moves;
            }
            continue;
        }
        if (trimmed[0] == '[') {
            state = .in_headers;

            if (std.mem.startsWith(u8, trimmed, "[White ")) {
                g.white = extractHeader(trimmed, arena.allocator());
            } else if (std.mem.startsWith(u8, trimmed, "[Black ")) {
                g.black = extractHeader(trimmed, arena.allocator());
            } else if (std.mem.startsWith(u8, trimmed, "[Result ")) {
                g.result = extractHeader(trimmed, arena.allocator());
            }
            continue;
        }

        if (state != .in_moves) continue;

        // remove comments
        var clean_line: [1024]u8 = undefined;
        const clean_len = stripCommentsAndVariations(trimmed, &clean_line, &depth_curly, &depth_paren);

        var iter = std.mem.tokenizeAny(u8, clean_line[0..clean_len], " \t.");
        while (iter.next()) |token| {
            if (std.mem.eql(u8, token, ".")) {
                continue;
            } else if (isMoveNumber(token)) {
                move_number = parseMoveNumber(token);
            } else {
                if (token.len == 0 or token.len > 10) continue;
                if (token[0] == '$') continue;
                if (std.mem.eql(u8, token, "1-0") or
                    std.mem.eql(u8, token, "0-1") or
                    std.mem.eql(u8, token, "1/2-1/2") or
                    std.mem.eql(u8, token, "*"))
                {
                    continue;
                }

                if (g.move_count >= g.moves.len) break; // safety!
                var m = &g.moves[g.move_count];

                m.move_number = move_number;
                m.player = next_player;
                m.move_text = try arena.allocator().dupe(u8, token);
                m.is_capture = std.mem.containsAtLeast(u8, token, 1, "x");
                m.is_castle = std.mem.containsAtLeast(u8, token, 1, "O-O");
                m.captured_piece = if (m.is_capture) parseCapturedPiece(token) else null;

                g.move_count += 1;
                next_player = if (next_player == 'W') 'B' else 'W';
            }
        }
    }

    if (g.move_count > 0 and g.white.len > 0 and g.black.len > 0) {
        if (isGameValid(&g)) {
            try emitGameSQL(&g, game_id, writer);
        }
    }
    try writer.writeAll("ALTER TABLE moves ENABLE KEYS;\n");
    try writer.writeAll("ALTER TABLE games ENABLE KEYS;\n");
    try writer.writeAll("ALTER TABLE players ENABLE KEYS;\n");
    try writer.writeAll("COMMIT;\n");
    try writer.flush();
}

fn isMoveNumber(token: []const u8) bool {
    var isNumber: bool = true;
    for (token) |c| {
        if (!std.ascii.isDigit(c)) {
            isNumber = false;
        }
    }
    return isNumber;
}

fn extractHeader(line: []const u8, alloc: std.mem.Allocator) []const u8 {
    const start = std.mem.indexOf(u8, line, "\"") orelse return "";
    const end = std.mem.indexOf(u8, line[start + 1 ..], "\"") orelse return "";
    const s = line[start + 1 .. start + 1 + end];
    return alloc.dupe(u8, s) catch "";
}

fn stripCommentsAndVariations(line: []const u8, out: *[1024]u8, depth_curly: *u8, depth_paren: *u8) usize {
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
            else => if (depth_curly.* == 0 and depth_paren.* == 0) {
                if (len < out.len) {
                    out[len] = c;
                    len += 1;
                }
            },
        }
    }
    return len;
}

fn fixMoveNumbers(line: []const u8, out: *[1024]u8) usize {
    // collapse "62 ." into "62."
    var len: usize = 0;
    var i: usize = 0;
    while (i < line.len) {
        if (i + 2 < line.len and
            std.ascii.isDigit(line[i]) and
            line[i + 1] == ' ' and
            line[i + 2] == '.')
        {
            out[len] = line[i];
            out[len + 1] = '.';
            len += 2;
            i += 3;
        } else {
            out[len] = line[i];
            len += 1;
            i += 1;
        }
    }
    return len;
}

fn parseMoveNumber(token: []const u8) u32 {
    var end = token.len;
    while (end > 0 and token[end - 1] == '.') {
        end -= 1;
    }
    if (end == 0) return 0;
    return std.fmt.parseInt(u32, token[0..end], 10) catch 0;
}

fn parseCapturedPiece(token: []const u8) ?u8 {
    for (token, 0..) |c, i| {
        if (c == 'x' and i + 1 < token.len) {
            const next = token[i + 1];
            if (std.ascii.isUpper(next)) return next;
        }
    }
    return null;
}

// fn emitEscaped(writer: *Writer, s: []const u8) !void {
//     for (s) |c| {
//         if (c == '\'') try writer.writeByte('\'');
//         try writer.writeByte(c);
//     }
// }

fn emitEscaped(writer: *Writer, s: []const u8) !void {
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

fn isGameValid(g: *Game) bool {
    if (g.white.len == 0 or g.black.len == 0) return false;

    for (1..g.move_count) |i| {
        const a = g.moves[i].move_number;
        const b = g.moves[i-1].move_number;
        const diff = if (a > b) a - b else b - a;
        if (diff > 2) return false;
    }
    return true;
}

fn emitGameSQL(g: *Game, game_id: u32, writer: *Writer) !void {
    // players insert
    try writer.writeAll("INSERT IGNORE INTO players(name) VALUES('");
    try emitEscaped(writer, g.white);
    try writer.writeAll("');\n");

    try writer.writeAll("INSERT IGNORE INTO players(name) VALUES('");
    try emitEscaped(writer, g.black);
    try writer.writeAll("');\n");

    // games insert
    try writer.writeAll("INSERT INTO games(id, white_player_id, black_player_id, result) VALUES (");
    try writer.print("{d}, (SELECT id FROM players WHERE name='", .{game_id});
    try emitEscaped(writer, g.white);
    try writer.writeAll("'), (SELECT id FROM players WHERE name='");
    try emitEscaped(writer, g.black);
    try writer.writeAll("'), '");
    try emitEscaped(writer, g.result);
    try writer.writeAll("');\n");

    // Moves insertion
    try writer.writeAll("INSERT INTO moves (game_id, move_number, player, move_text, is_capture, is_castle, captured_piece) VALUES\n");
    for (0..g.move_count) |i| {
        const m = g.moves[i];
        const is_capture: u1 = if (m.is_capture) 1 else 0;
        const is_castle: u1 = if (m.is_castle) 1 else 0;
        const sep = if (i == g.move_count - 1) ";\n" else ",\n";

        try writer.print("({d},{d},'{c}','", .{ game_id, m.move_number, m.player });
        try emitEscaped(writer, m.move_text);
        if (m.captured_piece) |cp| {
            try writer.print("',{d},{d},'{c}'){s}", .{ is_capture, is_castle, cp, sep });
        } else {
            try writer.print("',{d},{d},NULL){s}", .{ is_capture, is_castle, sep });
        }
    }
}
