// ©AngelaMos | 2026
// cli.zig

const std = @import("std");
const http = @import("http.zig");
const Allocator = std.mem.Allocator;

pub const default_ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " ++
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

pub const default_subs = [_][]const u8{
    "quant", "quantfinance",  "quant_hft",        "QuantFinanceJobs",
    "cpp",   "cpp_questions", "csMajors",         "cscareerquestions",
    "FPGA",  "algotrading",   "financialcareers", "leetcode",
};

pub const Config = struct {
    subreddits: []const []const u8 = &default_subs,
    max_posts: usize = 500,
    month_cap: usize = 200,
    top_n_comments: usize = 30,
    comments_per: usize = 15,
    data_dir: []const u8 = "data",
    throttle: http.Throttle = .{},
    ua: []const u8 = default_ua,
};

pub const Command = enum { scrape, analyze, help };
pub const Parsed = struct { cmd: Command, config: Config };

pub const Logger = struct {
    io: std.Io,
    start_ns: i96,

    pub fn init(io: std.Io) Logger {
        return .{ .io = io, .start_ns = std.Io.Timestamp.now(io, .awake).nanoseconds };
    }

    pub fn log(self: *const Logger, comptime fmt: []const u8, args: anytype) void {
        const elapsed = std.Io.Timestamp.now(self.io, .awake).nanoseconds - self.start_ns;
        const sec: u64 = @intCast(@max(@as(i96, 0), @divFloor(elapsed, std.time.ns_per_s)));
        std.debug.print("[{d:0>2}:{d:0>2}] ", .{ sec / 60, sec % 60 });
        std.debug.print(fmt ++ "\n", args);
    }
};

fn splitCsv(arena: Allocator, s: []const u8) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    var it = std.mem.tokenizeScalar(u8, s, ',');
    while (it.next()) |tok| try list.append(arena, try arena.dupe(u8, tok));
    return list.toOwnedSlice(arena);
}

pub fn parseArgs(arena: Allocator, args: []const [:0]const u8) !Parsed {
    var cfg = Config{};
    var cmd: Command = .help;
    var i: usize = 1;
    if (args.len > 1 and args[1].len > 0 and args[1][0] != '-') {
        if (std.mem.eql(u8, args[1], "scrape")) {
            cmd = .scrape;
        } else if (std.mem.eql(u8, args[1], "analyze")) {
            cmd = .analyze;
        }
        i = 2;
    }
    while (i + 1 < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--subs")) {
            i += 1;
            cfg.subreddits = try splitCsv(arena, args[i]);
        } else if (std.mem.eql(u8, a, "--max")) {
            i += 1;
            cfg.max_posts = std.fmt.parseInt(usize, args[i], 10) catch cfg.max_posts;
        } else if (std.mem.eql(u8, a, "--month-max")) {
            i += 1;
            cfg.month_cap = std.fmt.parseInt(usize, args[i], 10) catch cfg.month_cap;
        } else if (std.mem.eql(u8, a, "--top-comments")) {
            i += 1;
            cfg.top_n_comments = std.fmt.parseInt(usize, args[i], 10) catch cfg.top_n_comments;
        } else if (std.mem.eql(u8, a, "--per-comments")) {
            i += 1;
            cfg.comments_per = std.fmt.parseInt(usize, args[i], 10) catch cfg.comments_per;
        } else if (std.mem.eql(u8, a, "--data")) {
            i += 1;
            cfg.data_dir = try arena.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, a, "--base-ms")) {
            i += 1;
            cfg.throttle.base_ms = std.fmt.parseInt(u64, args[i], 10) catch cfg.throttle.base_ms;
        } else if (std.mem.eql(u8, a, "--jitter-ms")) {
            i += 1;
            cfg.throttle.jitter_ms = std.fmt.parseInt(u64, args[i], 10) catch cfg.throttle.jitter_ms;
        }
    }
    return .{ .cmd = cmd, .config = cfg };
}

pub fn printUsage() void {
    std.debug.print(
        \\erhm -- Reddit research scraper + analyzer, written in Zig for reasons that are none of your business
        \\
        \\usage:
        \\  erhm scrape  [--subs a,b,c] [--max 500] [--month-max 200]
        \\                  [--top-comments 30] [--per-comments 15] [--data data]
        \\                  [--base-ms 2500] [--jitter-ms 1500]
        \\  erhm analyze [--data data]
        \\
    , .{});
}
