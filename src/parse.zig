// ©AngelaMos | 2026
// parse.zig

const std = @import("std");
const model = @import("model.zig");
const Allocator = std.mem.Allocator;
const Post = model.Post;
const Comment = model.Comment;

pub const Listing = struct {
    posts: []Post,
    after: ?[]const u8,
};

pub const Thread = struct {
    selftext: []const u8,
    comments: []Comment,
};

fn tagAttr(tag: []const u8, name: []const u8) ?[]const u8 {
    var buf: [80]u8 = undefined;
    const needle = std.fmt.bufPrint(&buf, " {s}=\"", .{name}) catch return null;
    const at = std.mem.indexOf(u8, tag, needle) orelse return null;
    const start = at + needle.len;
    const end = std.mem.indexOfScalarPos(u8, tag, start, '"') orelse return null;
    return tag[start..end];
}

fn intAttr(tag: []const u8, name: []const u8) i64 {
    const v = tagAttr(tag, name) orelse return 0;
    return std.fmt.parseInt(i64, v, 10) catch 0;
}

fn appendEntity(arena: Allocator, out: *std.ArrayList(u8), ent: []const u8) !bool {
    const named = [_]struct { e: []const u8, v: []const u8 }{
        .{ .e = "amp", .v = "&" },     .{ .e = "lt", .v = "<" },     .{ .e = "gt", .v = ">" },
        .{ .e = "quot", .v = "\"" },   .{ .e = "apos", .v = "'" },   .{ .e = "nbsp", .v = " " },
        .{ .e = "#39", .v = "'" },     .{ .e = "#x27", .v = "'" },   .{ .e = "rsquo", .v = "'" },
        .{ .e = "lsquo", .v = "'" },   .{ .e = "ldquo", .v = "\"" }, .{ .e = "rdquo", .v = "\"" },
        .{ .e = "mdash", .v = "-" },   .{ .e = "ndash", .v = "-" },  .{ .e = "hellip", .v = "..." },
    };
    for (named) |kv| {
        if (std.mem.eql(u8, ent, kv.e)) {
            try out.appendSlice(arena, kv.v);
            return true;
        }
    }
    if (ent.len >= 2 and ent[0] == '#') {
        const cp: u21 = blk: {
            if (ent[1] == 'x' or ent[1] == 'X') break :blk std.fmt.parseInt(u21, ent[2..], 16) catch return false;
            break :blk std.fmt.parseInt(u21, ent[1..], 10) catch return false;
        };
        var enc: [4]u8 = undefined;
        const n = std.unicode.utf8Encode(cp, &enc) catch return false;
        try out.appendSlice(arena, enc[0..n]);
        return true;
    }
    return false;
}

fn extractText(arena: Allocator, frag: []const u8, max_len: usize) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.ensureTotalCapacity(arena, @min(frag.len, max_len) + 1);
    var i: usize = 0;
    var last_space = true;
    while (i < frag.len and out.items.len < max_len) {
        const c = frag[i];
        if (c == '<') {
            const close = std.mem.indexOfScalarPos(u8, frag, i, '>') orelse break;
            i = close + 1;
            if (!last_space) {
                try out.append(arena, ' ');
                last_space = true;
            }
            continue;
        }
        if (c == '&') {
            if (std.mem.indexOfScalarPos(u8, frag, i, ';')) |semi| {
                if (semi - i <= 12 and try appendEntity(arena, &out, frag[i + 1 .. semi])) {
                    i = semi + 1;
                    last_space = false;
                    continue;
                }
            }
        }
        if (c == ' ' or c == '\n' or c == '\t' or c == '\r') {
            if (!last_space) {
                try out.append(arena, ' ');
                last_space = true;
            }
            i += 1;
            continue;
        }
        try out.append(arena, c);
        last_space = false;
        i += 1;
    }
    var items = out.items;
    if (items.len > 0 and items[items.len - 1] == ' ') items = items[0 .. items.len - 1];
    return items;
}

fn classifyType(domain: []const u8) []const u8 {
    if (std.mem.startsWith(u8, domain, "self.")) return "text";
    const images = [_][]const u8{ "i.redd.it", "i.imgur.com", "imgur.com", "preview.redd.it" };
    for (images) |d| {
        if (std.mem.eql(u8, domain, d)) return "image";
    }
    if (std.mem.startsWith(u8, domain, "i.")) return "image";
    if (std.mem.indexOf(u8, domain, "gallery") != null) return "image";
    if (std.mem.eql(u8, domain, "v.redd.it") or std.mem.startsWith(u8, domain, "v.")) return "video";
    return "link";
}

fn fmtDate(arena: Allocator, ms: i64) ![]const u8 {
    const days = @divFloor(ms, 86_400_000);
    const z = days + 719_468;
    const era = @divFloor(if (z >= 0) z else z - 146_096, 146_097);
    const doe = z - era * 146_097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36_524) - @divFloor(doe, 146_096), 365);
    const y = yoe + era * 400;
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const d = doy - @divFloor(153 * mp + 2, 5) + 1;
    const m = if (mp < 10) mp + 3 else mp - 9;
    const year = if (m <= 2) y + 1 else y;
    return std.fmt.allocPrint(arena, "{d}-{d:0>2}-{d:0>2}", .{
        @as(u32, @intCast(year)),
        @as(u32, @intCast(m)),
        @as(u32, @intCast(d)),
    });
}

fn extractTitle(arena: Allocator, chunk: []const u8) ![]const u8 {
    const a = std.mem.indexOf(u8, chunk, "data-event-action=\"title\"") orelse return arena.dupe(u8, "");
    const gt = std.mem.indexOfScalarPos(u8, chunk, a, '>') orelse return arena.dupe(u8, "");
    const close = std.mem.indexOfPos(u8, chunk, gt + 1, "</a>") orelse return arena.dupe(u8, "");
    return extractText(arena, chunk[gt + 1 .. close], 1000);
}

fn extractBody(arena: Allocator, region: []const u8, max_len: usize) ![]const u8 {
    const ub = std.mem.indexOf(u8, region, "usertext-body") orelse return arena.dupe(u8, "");
    const md = std.mem.indexOfPos(u8, region, ub, "class=\"md\">") orelse return arena.dupe(u8, "");
    const start = md + "class=\"md\">".len;
    const end = std.mem.indexOfPos(u8, region, start, "</div>") orelse region.len;
    return extractText(arena, region[start..end], max_len);
}

fn permalink(arena: Allocator, tag: []const u8) ![]const u8 {
    const p = tagAttr(tag, "data-permalink") orelse return arena.dupe(u8, "");
    return std.fmt.allocPrint(arena, "https://old.reddit.com{s}", .{p});
}

fn findAfter(arena: Allocator, html: []const u8) ?[]const u8 {
    const nb = std.mem.indexOf(u8, html, "class=\"next-button\"") orelse return null;
    const a = std.mem.indexOfPos(u8, html, nb, "after=t3_") orelse return null;
    const start = a + "after=".len;
    var end = start;
    while (end < html.len) : (end += 1) {
        const c = html[end];
        const ok = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_';
        if (!ok) break;
    }
    return arena.dupe(u8, html[start..end]) catch null;
}

pub fn parseListing(arena: Allocator, html: []const u8, sub: []const u8, timeframe: []const u8) !Listing {
    var posts: std.ArrayList(Post) = .empty;
    const marker = " data-fullname=\"t3_";
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, html, pos, marker)) |m| {
        const tag_start = std.mem.lastIndexOf(u8, html[0..m], "<div") orelse {
            pos = m + marker.len;
            continue;
        };
        const tag_end = std.mem.indexOfScalarPos(u8, html, m, '>') orelse break;
        const tag = html[tag_start..tag_end];
        pos = tag_end + 1;
        if (tagAttr(tag, "data-promoted")) |p| {
            if (std.mem.eql(u8, p, "true")) continue;
        }
        const next_m = std.mem.indexOfPos(u8, html, pos, marker) orelse html.len;
        const chunk = html[tag_end..next_m];

        const id = tagAttr(tag, "data-fullname") orelse continue;
        const domain = tagAttr(tag, "data-domain") orelse "";
        const ts_ms: ?i64 = if (tagAttr(tag, "data-timestamp")) |t| (std.fmt.parseInt(i64, t, 10) catch null) else null;

        try posts.append(arena, .{
            .id = try arena.dupe(u8, id),
            .subreddit = try arena.dupe(u8, sub),
            .timeframe = try arena.dupe(u8, timeframe),
            .title = try extractTitle(arena, chunk),
            .score = intAttr(tag, "data-score"),
            .num_comments = intAttr(tag, "data-comments-count"),
            .post_type = try arena.dupe(u8, classifyType(domain)),
            .domain = try arena.dupe(u8, domain),
            .created_date = if (ts_ms) |ms| try fmtDate(arena, ms) else try arena.dupe(u8, ""),
            .timestamp_ms = ts_ms,
            .url = try arena.dupe(u8, tagAttr(tag, "data-url") orelse ""),
            .permalink = try permalink(arena, tag),
            .author = try arena.dupe(u8, tagAttr(tag, "data-author") orelse ""),
            .nsfw = if (tagAttr(tag, "data-nsfw")) |n| std.mem.eql(u8, n, "true") else false,
            .selftext_snippet = try extractBody(arena, chunk, 500),
        });
    }
    return .{ .posts = try posts.toOwnedSlice(arena), .after = findAfter(arena, html) };
}

fn scoreFromChunk(chunk: []const u8) i64 {
    const s = std.mem.indexOf(u8, chunk, "class=\"score") orelse return 0;
    const t = std.mem.indexOfPos(u8, chunk, s, "title=\"") orelse return 0;
    const start = t + "title=\"".len;
    const end = std.mem.indexOfScalarPos(u8, chunk, start, '"') orelse return 0;
    return std.fmt.parseInt(i64, chunk[start..end], 10) catch 0;
}

fn cmpScoreDesc(_: void, a: Comment, b: Comment) bool {
    return a.score > b.score;
}

pub fn parseComments(arena: Allocator, html: []const u8, limit: usize) !Thread {
    const first_t1 = std.mem.indexOf(u8, html, "data-fullname=\"t1_");
    const op_region = if (first_t1) |f| html[0..f] else html;
    const selftext = try extractBody(arena, op_region, 2000);

    var list: std.ArrayList(Comment) = .empty;
    const marker = " data-fullname=\"t1_";
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, html, pos, marker)) |m| {
        const tag_start = std.mem.lastIndexOf(u8, html[0..m], "<div") orelse {
            pos = m + marker.len;
            continue;
        };
        const tag_end = std.mem.indexOfScalarPos(u8, html, m, '>') orelse break;
        const tag = html[tag_start..tag_end];
        pos = tag_end + 1;
        const author = tagAttr(tag, "data-author") orelse "";
        if (std.mem.eql(u8, author, "[deleted]")) continue;
        const next_m = std.mem.indexOfPos(u8, html, pos, marker) orelse html.len;
        const chunk = html[tag_end..next_m];
        const body = try extractBody(arena, chunk, 4000);
        if (body.len == 0 or std.mem.eql(u8, body, "[deleted]") or std.mem.eql(u8, body, "[removed]")) continue;
        try list.append(arena, .{
            .id = try arena.dupe(u8, tagAttr(tag, "data-fullname") orelse ""),
            .author = try arena.dupe(u8, author),
            .score = scoreFromChunk(chunk),
            .body = body,
        });
    }
    const items = try list.toOwnedSlice(arena);
    std.mem.sort(Comment, items, {}, cmpScoreDesc);
    return .{ .selftext = selftext, .comments = if (items.len > limit) items[0..limit] else items };
}
