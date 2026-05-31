// ©AngelaMos | 2026
// scrape.zig

const std = @import("std");
const http = @import("http.zig");
const parse = @import("parse.zig");
const model = @import("model.zig");
const cli = @import("cli.zig");
const Allocator = std.mem.Allocator;

const SubStat = struct {
    subreddit: []const u8,
    posts: usize,
    comment_threads: usize,
};

const Status = struct {
    generated_unix: i64,
    total_requests: usize,
    total_posts: usize,
    total_comment_threads: usize,
    per_subreddit: []const SubStat,
};

fn cmpPostScoreDesc(_: void, a: model.Post, b: model.Post) bool {
    return a.score > b.score;
}

fn writeJson(arena: Allocator, io: std.Io, cwd: std.Io.Dir, path: []const u8, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(arena, value, .{ .whitespace = .indent_2 });
    try cwd.writeFile(io, .{ .sub_path = path, .data = bytes });
}

fn scrapeListing(f: *http.Fetcher, arena: Allocator, log: *const cli.Logger, sub: []const u8, tf: []const u8, max: usize) ![]model.Post {
    var collected: std.ArrayList(model.Post) = .empty;
    var seen = std.StringHashMap(void).init(f.gpa);
    defer seen.deinit();
    var after: ?[]const u8 = null;
    var page: usize = 0;
    while (collected.items.len < max) {
        page += 1;
        const url = if (after) |a|
            try std.fmt.allocPrint(arena, "https://old.reddit.com/r/{s}/top/?t={s}&limit=100&count={d}&after={s}", .{ sub, tf, collected.items.len, a })
        else
            try std.fmt.allocPrint(arena, "https://old.reddit.com/r/{s}/top/?t={s}&limit=100", .{ sub, tf });
        const html = (try f.get(url)) orelse {
            log.log("  [{s}] {s}: fetch failed on page {d}, stopping", .{ sub, tf, page });
            break;
        };
        defer f.gpa.free(html);
        const listing = try parse.parseListing(arena, html, sub, tf);
        if (listing.posts.len == 0) {
            log.log("  [{s}] {s}: empty page {d}, stopping", .{ sub, tf, page });
            break;
        }
        const before = collected.items.len;
        for (listing.posts) |p| {
            const gop = try seen.getOrPut(p.id);
            if (!gop.found_existing) try collected.append(arena, p);
        }
        const added = collected.items.len - before;
        log.log("  [{s}] {s}: page {d} -> {d} posts ({d} new, total {d})", .{ sub, tf, page, listing.posts.len, added, collected.items.len });
        if (added == 0) {
            log.log("  [{s}] {s}: no new posts, end of listing", .{ sub, tf });
            break;
        }
        if (listing.after) |a| {
            if (after) |prev| {
                if (std.mem.eql(u8, prev, a)) break;
            }
            after = a;
        } else {
            break;
        }
    }
    return collected.items;
}

fn scrapeCommentsFor(f: *http.Fetcher, arena: Allocator, p: model.Post, per: usize) !?model.CommentThread {
    const url = try std.fmt.allocPrint(arena, "{s}?sort=top&limit={d}", .{ p.permalink, per + 10 });
    const html = (try f.get(url)) orelse return null;
    defer f.gpa.free(html);
    const th = try parse.parseComments(arena, html, per);
    return .{
        .post_id = p.id,
        .subreddit = p.subreddit,
        .title = p.title,
        .score = p.score,
        .permalink = p.permalink,
        .selftext = th.selftext,
        .comments = th.comments,
    };
}

pub fn run(gpa: Allocator, arena: Allocator, io: std.Io, log: *const cli.Logger, cfg: cli.Config) !void {
    var f = http.Fetcher.init(gpa, io, cfg.throttle, cfg.ua);
    defer f.deinit();

    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, cfg.data_dir);
    const raw_dir = try std.fmt.allocPrint(arena, "{s}/raw", .{cfg.data_dir});
    try cwd.createDirPath(io, raw_dir);

    log.log("=== Reddit research pull starting ({d} subreddits) ===", .{cfg.subreddits.len});
    if (f.get("https://old.reddit.com/") catch null) |h| f.gpa.free(h);

    var all_posts: std.ArrayList(model.Post) = .empty;
    var all_threads: std.ArrayList(model.CommentThread) = .empty;
    var stats: std.ArrayList(SubStat) = .empty;

    for (cfg.subreddits) |sub| {
        log.log("--- r/{s} ---", .{sub});
        const year_posts = try scrapeListing(&f, arena, log, sub, "year", cfg.max_posts);
        if (year_posts.len == 0) {
            log.log("  [{s}] no posts (private/banned/empty?) -> SKIPPING", .{sub});
            try stats.append(arena, .{ .subreddit = sub, .posts = 0, .comment_threads = 0 });
            continue;
        }
        const month_posts = try scrapeListing(&f, arena, log, sub, "month", cfg.month_cap);

        var by_id = std.StringHashMap(usize).init(gpa);
        defer by_id.deinit();
        var merged: std.ArrayList(model.Post) = .empty;
        for (year_posts) |p| {
            const gop = try by_id.getOrPut(p.id);
            if (!gop.found_existing) {
                gop.value_ptr.* = merged.items.len;
                try merged.append(arena, p);
            }
        }
        for (month_posts) |p| {
            const gop = try by_id.getOrPut(p.id);
            if (gop.found_existing) {
                merged.items[gop.value_ptr.*].timeframe = "year+month";
            } else {
                gop.value_ptr.* = merged.items.len;
                try merged.append(arena, p);
            }
        }
        const sub_posts = merged.items;

        try writeJson(arena, io, cwd, try std.fmt.allocPrint(arena, "{s}/{s}_posts.json", .{ raw_dir, sub }), sub_posts);
        log.log("  [{s}] saved {d} unique posts (year={d}, month={d})", .{ sub, sub_posts.len, year_posts.len, month_posts.len });

        const ranked = try arena.dupe(model.Post, sub_posts);
        std.mem.sort(model.Post, ranked, {}, cmpPostScoreDesc);
        const top = if (ranked.len > cfg.top_n_comments) ranked[0..cfg.top_n_comments] else ranked;
        log.log("  [{s}] diving comments on top {d} posts...", .{ sub, top.len });

        var sub_threads: std.ArrayList(model.CommentThread) = .empty;
        for (top, 1..) |p, idx| {
            if (try scrapeCommentsFor(&f, arena, p, cfg.comments_per)) |th| try sub_threads.append(arena, th);
            if (idx % 5 == 0) log.log("  [{s}] comments {d}/{d} done", .{ sub, idx, top.len });
        }
        try writeJson(arena, io, cwd, try std.fmt.allocPrint(arena, "{s}/{s}_comments.json", .{ raw_dir, sub }), sub_threads.items);
        log.log("  [{s}] saved {d} comment-threads (total reqs={d})", .{ sub, sub_threads.items.len, f.req_count });

        try all_posts.appendSlice(arena, sub_posts);
        try all_threads.appendSlice(arena, sub_threads.items);
        try stats.append(arena, .{ .subreddit = sub, .posts = sub_posts.len, .comment_threads = sub_threads.items.len });

        try writeJson(arena, io, cwd, try std.fmt.allocPrint(arena, "{s}/all_posts.json", .{cfg.data_dir}), all_posts.items);
        try writeJson(arena, io, cwd, try std.fmt.allocPrint(arena, "{s}/all_comments.json", .{cfg.data_dir}), all_threads.items);
    }

    const gen = std.Io.Timestamp.now(io, .real).nanoseconds;
    try writeJson(arena, io, cwd, try std.fmt.allocPrint(arena, "{s}/scrape_status.json", .{cfg.data_dir}), Status{
        .generated_unix = @intCast(@divFloor(gen, std.time.ns_per_s)),
        .total_requests = f.req_count,
        .total_posts = all_posts.items.len,
        .total_comment_threads = all_threads.items.len,
        .per_subreddit = stats.items,
    });
    log.log("=== scrape complete: {d} posts / {d} threads / {d} requests ===", .{ all_posts.items.len, all_threads.items.len, f.req_count });
}
