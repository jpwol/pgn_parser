const std = @import("std");
const allocator = std.heap.page_allocator;
const globals = @import("globals.zig");
const Game = globals.Game;
const Move = globals.Move;
const Writer = std.io.Writer;

const h = @import("helpers.zig");
const e = @import("emitter.zig");
const Engine = @import("engine.zig").Game_Engine;

pub fn main() !u8 {
    const stdout = std.fs.File.stdout();
    const stderr = std.fs.File.stderr();
    var buf: [1024]u8 = undefined;

    var ww = stdout.writer(&buf);
    var ew = stderr.writer(&.{});
    const writer = &ww.interface;
    const err_writer = &ew.interface;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        try err_writer.print("usage: parse <file>\n", .{});
        return 1;
    }

    const file_string = args[1];
    const pgn_file = std.fs.cwd().openFile(file_string, .{}) catch |err| {
        try h.print_error(err_writer);
        try err_writer.print("Couldn't open file {s}: {}\n", .{ file_string, err });
        return 1;
    };
    defer pgn_file.close();
    try h.print_info(writer);
    try writer.print("File \"{s}\" opened successfully\n", .{file_string});
    try writer.flush();

    try h.print_info(writer);
    try writer.writeAll("Creating directory \"emit\"\n");
    if (std.fs.cwd().makeDir("emit")) |_| {
        try h.print_info(writer);
        try writer.writeAll("Directory \"emit\" created successfully\n");
    } else |err| {
        switch (err) {
            std.fs.Dir.MakeError.PathAlreadyExists => {
                try h.print_warn(writer);
                try writer.writeAll("Directory \"emit\" already exists, skipping...\n");
            },
            else => {
                try h.print_error(err_writer);
                try err_writer.print("{}\n", .{err});
                return 1;
            },
        }
    }
    try writer.flush();

    try h.print_info(writer);
    try writer.writeAll("Creating file \"emit/players.csv\"\n");
    const players_file = try std.fs.cwd().createFile("./emit/players.csv", .{});
    defer players_file.close();

    try h.print_info(writer);
    try writer.writeAll("Creating file \"emit/games.csv\"\n");
    const games_file = try std.fs.cwd().createFile("./emit/games.csv", .{});
    defer games_file.close();

    try h.print_info(writer);
    try writer.writeAll("Creating file \"emit/moves.csv\"\n");
    const moves_file = try std.fs.cwd().createFile("./emit/moves.csv", .{});
    defer moves_file.close();

    try h.print_info(writer);
    try writer.writeAll("Creating file \"emit/state.csv\"\n");
    const state_file = try std.fs.cwd().createFile("./emit/state.csv", .{});
    defer state_file.close();

    try writer.flush();

    var pgn_buf: [1024]u8 = undefined;
    var players_buf: [65536]u8 = undefined;
    var games_buf: [65536]u8 = undefined;
    var moves_buf: [65536]u8 = undefined;
    var state_buf: [65536]u8 = undefined;

    var rw = pgn_file.reader(&pgn_buf);
    var pw = players_file.writer(&players_buf);
    var gw = games_file.writer(&games_buf);
    var mw = moves_file.writer(&moves_buf);
    var sw = state_file.writer(&state_buf);

    const reader = &rw.interface;
    const players_writer = &pw.interface;
    const games_writer = &gw.interface;
    const moves_writer = &mw.interface;
    const state_writer = &sw.interface;

    var players_map = std.StringHashMap(u32).init(allocator);
    defer players_map.deinit();

    var g: Game = std.mem.zeroes(Game);
    var game_id: u32 = 1;
    var move_number: u32 = 0;
    var next_player: u8 = 'W';

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    var game_arena = std.heap.ArenaAllocator.init(gpa_allocator);
    defer game_arena.deinit();

    var player_arena = std.heap.ArenaAllocator.init(gpa_allocator);
    defer player_arena.deinit();

    var depth_curly: u8 = 0;
    var depth_paren: u8 = 0;
    var depth_square: u8 = 0;

    const ParseState = enum { waiting, in_headers, in_moves };
    var state: ParseState = .waiting;

    try h.print_info(writer);
    try writer.writeAll("Getting file line count\n");
    try writer.flush();
    const total_lines = try h.getLineCount(reader);
    var current_line: u32 = 0;
    try h.print_info(writer);
    try writer.print("Total lines in file: {d}\n", .{total_lines});
    try writer.flush();
    try rw.seekTo(0);

    var invalid_games: u32 = 0;
    var skipped_games: u32 = 0;
    var valid_games: u32 = 0;

    while (true) {
        const line = try reader.takeDelimiter('\n');
        if (line == null) break;
        current_line += 1;
        if (current_line % 10000 == 0) {
            try h.printProgressBar(writer, current_line, total_lines, 30);
            try writer.flush();
        }
        const l = line.?;
        const trimmed = std.mem.trim(u8, l, " \t\n\r");

        if (trimmed.len == 0) {
            if (state == .in_moves) {
                if (g.move_count > 0 and g.white.len > 0 and g.black.len > 0) {
                    if (h.isGameValid(&g) and depth_paren == 0 and depth_curly == 0) {
                        var engine: Engine = .{};
                        try engine.evaluate(g, game_id, state_writer);
                        try e.emitGameCSV(&g, game_id, &players_map, players_writer, games_writer, moves_writer);
                        valid_games += 1;
                        game_id += 1;
                    } else {
                        invalid_games += 1;
                    }

                    g = std.mem.zeroes(Game);
                    _ = game_arena.reset(.retain_capacity);

                    depth_curly = 0;
                    depth_paren = 0;

                    move_number = 0;
                    next_player = 'W';
                } else {
                    skipped_games += 1;
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
                g.white = h.extractHeader(trimmed, player_arena.allocator());
            } else if (std.mem.startsWith(u8, trimmed, "[Black ")) {
                g.black = h.extractHeader(trimmed, player_arena.allocator());
            } else if (std.mem.startsWith(u8, trimmed, "[Result ")) {
                g.result = h.extractHeader(trimmed, game_arena.allocator());
            }
            continue;
        }

        if (state != .in_moves) continue;

        // remove comments
        var clean_line: [1024]u8 = undefined;
        const clean_len = h.stripCommentsAndVariations(trimmed, &clean_line, &depth_curly, &depth_paren, &depth_square);

        var iter = std.mem.tokenizeAny(u8, clean_line[0..clean_len], " \t.");
        while (iter.next()) |token| {
            if (std.mem.eql(u8, token, ".")) {
                continue;
            } else if (h.isMoveNumber(token)) {
                move_number = h.parseMoveNumber(token);
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
                m.move_text = try game_arena.allocator().dupe(u8, token);

                g.move_count += 1;
                next_player = if (next_player == 'W') 'B' else 'W';
            }
        }
    }

    if (g.move_count > 0 and g.white.len > 0 and g.black.len > 0) {
        if (h.isGameValid(&g)) {
            var engine: Engine = .{};
            try engine.evaluate(g, game_id, state_writer);
            try e.emitGameCSV(&g, game_id, &players_map, players_writer, games_writer, moves_writer);
            valid_games += 1;
        } else {
            invalid_games += 1;
        }
    }

    try h.printProgressBar(writer, current_line, total_lines, 30);
    try writer.writeByte('\n');
    try h.print_info(writer);
    try writer.print("Valid games: {d}\n", .{valid_games});
    if (invalid_games > 0) {
        try h.print_warn(writer);
        try writer.print("Invalid games: {d}\n", .{invalid_games});
    }
    if (skipped_games > 0) {
        try h.print_warn(writer);
        try writer.print("Skipped games: {d}\n", .{skipped_games});
    }
    try h.print_info(writer);
    try writer.print("Total games: {d}\n", .{valid_games + invalid_games + skipped_games});
    try writer.flush();
    try players_writer.flush();
    try games_writer.flush();
    try moves_writer.flush();
    try state_writer.flush();

    return 0;
}
