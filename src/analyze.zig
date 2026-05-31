// ©AngelaMos | 2026
// analyze.zig

const std = @import("std");
const model = @import("model.zig");
const cli = @import("cli.zig");
const Allocator = std.mem.Allocator;

const Example = struct { title: []const u8, score: i64, sub: []const u8 };
const SubPerf = struct { sub: []const u8, ratio: f64 };
const Cluster = struct {
    name: []const u8,
    count: usize,
    median_score: f64,
    examples: []const Example,
    overperformance_by_sub: []const SubPerf,
};
const Gram = struct { phrase: []const u8, count: usize };
const Unigram = struct { word: []const u8, count: usize };
const PainExample = struct { body: []const u8, score: i64, sub: []const u8 };
const Pain = struct { theme: []const u8, mentions: usize, examples: []const PainExample };
const FormatStat = struct { post_type: []const u8, n: usize, median: f64, mean: f64 };
const SubFormat = struct { sub: []const u8, types: []const FormatStat };
const HeatTerm = struct { term: []const u8, raw_mentions: usize, score_weighted: i64 };
const Heatmap = struct {
    firms: []const HeatTerm,
    languages: []const HeatTerm,
    concepts: []const HeatTerm,
    comp_signals: []const HeatTerm,
};
const TopPost = struct { title: []const u8, score: i64, sub: []const u8, post_type: []const u8, comments: i64 };
const SubCount = struct { sub: []const u8, count: usize };
const SubMedian = struct { sub: []const u8, median: f64 };
const Totals = struct { posts: usize, comment_threads: usize, comments: usize, subreddits: []const []const u8 };
const Analysis = struct {
    totals: Totals,
    per_sub_counts: []const SubCount,
    sub_median_score: []const SubMedian,
    title_clusters: []const Cluster,
    hook_title_ngrams: []const Gram,
    hook_title_ngrams_topposts: []const Gram,
    hook_comment_ngrams: []const Gram,
    hook_title_unigrams: []const Unigram,
    hook_comment_unigrams: []const Unigram,
    pain_points: []const Pain,
    format_winners: []const SubFormat,
    format_global: []const FormatStat,
    topic_heatmap: Heatmap,
    top_posts_overall: []const TopPost,
};

const post_types = [_][]const u8{ "text", "image", "video", "link" };

const qwords = [_][]const u8{ "how", "what", "why", "is", "are", "should", "can", "do", "does", "which", "who", "when", "where", "would", "could", "will", "any" };
const outrage = [_][]const u8{ "rant", "scam", "joke", "rigged", "broken", "ridiculous", "insane", "cope", "cooked", "wtf", "fuck", "fck", "hate", "stupid", "trash", "garbage", "clown" };
const numbered_nouns = [_][]const u8{ "things", "tips", "ways", "reasons", "lessons", "mistakes", "steps" };
const screenshot_words = [_][]const u8{ "screenshot", "look at this", "this email", "got this", "check this", "spotted", "seen" };
const advice_words = [_][]const u8{ "guide", "roadmap", "how i", "how to", "tips", "what i learned", "lessons", "advice", "prep", "cheat sheet", "cheatsheet", "resource", "resources" };
const identity_words = [_][]const u8{ "i'm a", "im a", "as a", "quant at", "working at", "i work" };
const help_words = [_][]const u8{ "help", "need advice", "please", "stuck", "rejected", "failed", "ghosted", "desperate", "struggling", "lost", "confused" };
const confession_words = [_][]const u8{ "i got", "got an offer", "got offer", "offer from", "offer at", "i landed", "i accepted", "i received", "i signed", "i'm in", "im in", "i passed", "i made it", "update:", "finally" };
const comp_words = [_][]const u8{ "salary", "comp", "total comp", "tc", "base", "bonus", "pay", "six figure" };

const firms = [_][]const u8{ "jane street", "jane st", "optiver", "citadel", "citsec", "renaissance", "rentec", "imc", "akuna", "virtu", "tower", "drw", "de shaw", "d.e. shaw", "deshaw", "hudson river", "hrt", "jump", "two sigma", "sig", "five rings", "headlands", "old mission", "flow traders", "qrt", "millennium", "point72", "squarepoint", "marshall wace", "g-research", "g research" };
const langs = [_][]const u8{ "c++", "cpp", "python", "rust", "ocaml", "java", "kotlin", "verilog", "vhdl", "fpga", "sql", "matlab", "haskell", "kdb", "q/kdb" };
const concepts = [_][]const u8{ "leetcode", "brainteaser", "brain teaser", "probability", "expected value", "mental math", "market making", "hft", "low latency", "options", "derivatives", "machine learning", "ml", "statistics", "stochastic", "linear algebra", "data structures", "system design", "order book", "backtest", "alpha", "signal", "pnl", "online assessment", "oa", "superday", "onsite", "referral", "internship", "new grad", "phd", "quant dev", "quant research", "qr", "qt" };
const comp_signals = [_][]const u8{ "$", "total comp", "tc", "six figure", "six figures", "half a mill", "million", "base", "bonus" };

const pain_themes = [_]struct { name: []const u8, words: []const []const u8 }{
    .{ .name = "leetcode_grind", .words = &.{ "leetcode", "lc", "grind", "grinding", "problems a day", "neetcode", "memoriz" } },
    .{ .name = "rejection_cope", .words = &.{ "reject", "rejection", "ghosted", "no offer", "didn't get", "didnt get", "failed", "cope", "cooked", "over for me", "ngmi" } },
    .{ .name = "pedigree_gatekeep", .words = &.{ "target school", "non-target", "nontarget", "ivy", "pedigree", "prestige", "phd", "mit", "harvard", "princeton", "olympiad", "imo", "putnam", "gpa" } },
    .{ .name = "oversaturation", .words = &.{ "saturat", "oversaturat", "too many", "crowded", "cooked", "no jobs", "impossible now", "market is" } },
    .{ .name = "imposter_doubt", .words = &.{ "imposter", "not smart enough", "good enough", "dumb", "stupid", "out of my league", "intimidat", "nervous", "anxious", "scared" } },
    .{ .name = "oa_assessment", .words = &.{ "oa", "online assessment", "hackerrank", "codesignal", "take home", "take-home", "timed test", "coding challenge" } },
    .{ .name = "brainteasers_prob", .words = &.{ "brainteaser", "brain teaser", "probability", "expected value", "ev", "mental math", "estimation", "dice", "coin", "cards", "markov" } },
    .{ .name = "comp_confusion", .words = &.{ "comp", "tc", "total comp", "salary", "bonus", "how much", "underpaid", "lowball", "pay" } },
    .{ .name = "visa_sponsorship", .words = &.{ "visa", "sponsor", "h1b", "opt", "citizen", "international", "green card", "relocat" } },
    .{ .name = "age_late", .words = &.{ "too old", "too late", "age", "career chang", "second career", "30s", "late start" } },
    .{ .name = "luck_rng", .words = &.{ "luck", "lucky", "rng", "random", "lottery", "crapshoot", "right place", "connections", "referral" } },
    .{ .name = "cpp_hard", .words = &.{ "c++", "cpp", "templates", "undefined behavior", "segfault", "pointers", "memory", "rust" } },
    .{ .name = "prep_paralysis", .words = &.{ "where do i", "where to start", "how do i", "how to prep", "overwhelm", "don't know", "dont know", "too much", "so much to", "roadmap" } },
    .{ .name = "interview_anxiety", .words = &.{ "interview", "onsite", "final round", "superday", "mock", "nervous", "freeze", "froze", "blank" } },
};

const stop_words = [_][]const u8{ "a", "an", "the", "and", "or", "but", "of", "to", "in", "on", "for", "with", "at", "by", "from", "is", "are", "was", "were", "be", "been", "being", "this", "that", "these", "those", "it", "its", "as", "i", "you", "he", "she", "they", "we", "my", "your", "our", "their", "his", "her", "them", "me", "us", "do", "does", "did", "doing", "have", "has", "had", "having", "will", "would", "could", "should", "can", "may", "might", "must", "not", "no", "yes", "if", "so", "than", "then", "there", "here", "what", "which", "who", "whom", "whose", "when", "where", "why", "how", "all", "any", "both", "each", "few", "more", "most", "other", "some", "such", "only", "own", "same", "too", "very", "just", "about", "into", "over", "after", "before", "between", "out", "up", "down", "get", "got", "getting", "one", "two", "also", "even", "really", "much", "many", "lot", "like", "im", "ive", "dont", "cant", "vs" };

fn isAlnum(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9');
}

fn isTokChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '\'' or c == '+' or c == '#';
}

fn lowerDup(arena: Allocator, s: []const u8) ![]u8 {
    const out = try arena.alloc(u8, s.len);
    for (s, 0..) |c, i| out[i] = std.ascii.toLower(c);
    return out;
}

fn hasWord(hay: []const u8, needle: []const u8) bool {
    return countWord(hay, needle) > 0;
}

fn countWord(hay: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;
    var n: usize = 0;
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, hay, start, needle)) |p| {
        const before_ok = p == 0 or !isAlnum(hay[p - 1]);
        const end = p + needle.len;
        const after_ok = end == hay.len or !isAlnum(hay[end]);
        if (before_ok and after_ok) n += 1;
        start = p + 1;
    }
    return n;
}

fn countPlain(hay: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;
    var n: usize = 0;
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, hay, start, needle)) |p| {
        n += 1;
        start = p + needle.len;
    }
    return n;
}

fn anyWord(hay: []const u8, words: []const []const u8) bool {
    for (words) |w| {
        if (hasWord(hay, w)) return true;
    }
    return false;
}

fn upperRatio(s: []const u8) bool {
    if (s.len <= 10) return false;
    var up: usize = 0;
    for (s) |c| {
        if (c >= 'A' and c <= 'Z') up += 1;
    }
    return up * 2 > s.len;
}

fn digitThenK(s: []const u8) bool {
    var i: usize = 0;
    while (i + 1 < s.len) : (i += 1) {
        if (s[i] >= '0' and s[i] <= '9' and s[i + 1] == 'k') return true;
    }
    return false;
}

fn firstWordIn(lower: []const u8, set: []const []const u8) bool {
    var end: usize = 0;
    while (end < lower.len and lower[end] != ' ') : (end += 1) {}
    const fw = lower[0..end];
    for (set) |w| {
        if (std.mem.eql(u8, fw, w)) return true;
    }
    return false;
}

fn medianOf(arena: Allocator, vals: []const i64) !f64 {
    if (vals.len == 0) return 0;
    const copy = try arena.dupe(i64, vals);
    std.mem.sort(i64, copy, {}, std.sort.asc(i64));
    const n = copy.len;
    if (n % 2 == 1) return @floatFromInt(copy[n / 2]);
    const a: f64 = @floatFromInt(copy[n / 2 - 1]);
    const b: f64 = @floatFromInt(copy[n / 2]);
    return (a + b) / 2.0;
}

fn round1(x: f64) f64 {
    return @round(x * 10.0) / 10.0;
}

fn shQuestion(t: []const u8, lower: []const u8, _: []const u8) bool {
    if (std.mem.endsWith(u8, std.mem.trimEnd(u8, t, " "), "?")) return true;
    return firstWordIn(lower, &qwords);
}
fn shConfession(_: []const u8, lower: []const u8, _: []const u8) bool {
    return anyWord(lower, &confession_words);
}
fn shOutrage(t: []const u8, lower: []const u8, _: []const u8) bool {
    return anyWord(lower, &outrage) or upperRatio(t);
}
fn shWorth(_: []const u8, lower: []const u8, _: []const u8) bool {
    return hasWord(lower, "worth");
}
fn shNumbered(_: []const u8, lower: []const u8, _: []const u8) bool {
    if (lower.len > 0 and lower[0] >= '0' and lower[0] <= '9') return true;
    if (std.mem.indexOf(u8, lower, "top ")) |ti| {
        if (ti + 4 < lower.len and lower[ti + 4] >= '0' and lower[ti + 4] <= '9') return true;
    }
    for (numbered_nouns) |noun| {
        var start: usize = 0;
        while (std.mem.indexOfPos(u8, lower, start, noun)) |p| {
            var j = p;
            while (j > 0 and lower[j - 1] == ' ') j -= 1;
            if (j > 0 and lower[j - 1] >= '0' and lower[j - 1] <= '9') return true;
            start = p + 1;
        }
    }
    return false;
}
fn shScreenshot(_: []const u8, lower: []const u8, ptype: []const u8) bool {
    return std.mem.eql(u8, ptype, "image") or anyWord(lower, &screenshot_words);
}
fn shAdvice(_: []const u8, lower: []const u8, _: []const u8) bool {
    return anyWord(lower, &advice_words);
}
fn shComparison(_: []const u8, lower: []const u8, _: []const u8) bool {
    return hasWord(lower, "vs") or std.mem.indexOf(u8, lower, " or ") != null or hasWord(lower, "better than");
}
fn shIdentity(_: []const u8, lower: []const u8, _: []const u8) bool {
    return anyWord(lower, &identity_words);
}
fn shHelp(_: []const u8, lower: []const u8, _: []const u8) bool {
    return anyWord(lower, &help_words);
}
fn shCompSalary(_: []const u8, lower: []const u8, _: []const u8) bool {
    return std.mem.indexOfScalar(u8, lower, '$') != null or anyWord(lower, &comp_words) or digitThenK(lower);
}

const Shape = struct { name: []const u8, f: *const fn ([]const u8, []const u8, []const u8) bool };
const shapes = [_]Shape{
    .{ .name = "question", .f = shQuestion },
    .{ .name = "confession_offer", .f = shConfession },
    .{ .name = "outrage_rant", .f = shOutrage },
    .{ .name = "is_x_worth_it", .f = shWorth },
    .{ .name = "numbered_list", .f = shNumbered },
    .{ .name = "screenshot_bait", .f = shScreenshot },
    .{ .name = "advice_guide", .f = shAdvice },
    .{ .name = "comparison_vs", .f = shComparison },
    .{ .name = "identity_flex", .f = shIdentity },
    .{ .name = "help_desperation", .f = shHelp },
    .{ .name = "comp_salary", .f = shCompSalary },
};

fn cmpGramDesc(_: void, a: Gram, b: Gram) bool {
    return a.count > b.count;
}
fn cmpUniDesc(_: void, a: Unigram, b: Unigram) bool {
    return a.count > b.count;
}
fn cmpHeatDesc(_: void, a: HeatTerm, b: HeatTerm) bool {
    return a.score_weighted > b.score_weighted;
}
fn cmpPainDesc(_: void, a: Pain, b: Pain) bool {
    return a.mentions > b.mentions;
}
fn cmpClusterMedianDesc(_: void, a: Cluster, b: Cluster) bool {
    return a.median_score > b.median_score;
}
fn cmpPostDesc(_: void, a: model.Post, b: model.Post) bool {
    return a.score > b.score;
}
fn cmpPerfDesc(_: void, a: SubPerf, b: SubPerf) bool {
    return a.ratio > b.ratio;
}
fn strLess(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn buildStopSet(arena: Allocator) !std.StringHashMap(void) {
    var set = std.StringHashMap(void).init(arena);
    for (stop_words) |w| try set.put(w, {});
    return set;
}

fn tokenize(arena: Allocator, lower: []const u8, stop: *std.StringHashMap(void)) ![][]const u8 {
    var toks: std.ArrayList([]const u8) = .empty;
    var i: usize = 0;
    while (i < lower.len) {
        while (i < lower.len and !isTokChar(lower[i])) i += 1;
        const start = i;
        while (i < lower.len and isTokChar(lower[i])) i += 1;
        if (i > start) {
            const w = lower[start..i];
            if (w.len > 1 and !stop.contains(w)) try toks.append(arena, w);
        }
    }
    return toks.toOwnedSlice(arena);
}

fn ngrams(arena: Allocator, texts: []const []const u8, stop: *std.StringHashMap(void), top: usize, min_count: usize) ![]Gram {
    var counts = std.StringHashMap(usize).init(arena);
    for (texts) |t| {
        const low = try lowerDup(arena, t);
        const toks = try tokenize(arena, low, stop);
        const ns = [_]usize{ 2, 3 };
        for (ns) |n| {
            if (toks.len < n) continue;
            var i: usize = 0;
            while (i + n <= toks.len) : (i += 1) {
                const gram = try std.mem.join(arena, " ", toks[i .. i + n]);
                const gop = try counts.getOrPut(gram);
                if (gop.found_existing) gop.value_ptr.* += 1 else gop.value_ptr.* = 1;
            }
        }
    }
    var out: std.ArrayList(Gram) = .empty;
    var it = counts.iterator();
    while (it.next()) |e| {
        if (e.value_ptr.* >= min_count) try out.append(arena, .{ .phrase = e.key_ptr.*, .count = e.value_ptr.* });
    }
    std.mem.sort(Gram, out.items, {}, cmpGramDesc);
    return if (out.items.len > top) out.items[0..top] else out.items;
}

fn unigrams(arena: Allocator, texts: []const []const u8, stop: *std.StringHashMap(void), top: usize, min_count: usize) ![]Unigram {
    var counts = std.StringHashMap(usize).init(arena);
    for (texts) |t| {
        const low = try lowerDup(arena, t);
        const toks = try tokenize(arena, low, stop);
        for (toks) |w| {
            if (w.len < 3 or !(w[0] >= 'a' and w[0] <= 'z')) continue;
            const gop = try counts.getOrPut(w);
            if (gop.found_existing) gop.value_ptr.* += 1 else gop.value_ptr.* = 1;
        }
    }
    var out: std.ArrayList(Unigram) = .empty;
    var it = counts.iterator();
    while (it.next()) |e| {
        if (e.value_ptr.* >= min_count) try out.append(arena, .{ .word = e.key_ptr.*, .count = e.value_ptr.* });
    }
    std.mem.sort(Unigram, out.items, {}, cmpUniDesc);
    return if (out.items.len > top) out.items[0..top] else out.items;
}

fn tally(arena: Allocator, terms: []const []const u8, texts: []const []const u8, weights: []const i64) ![]HeatTerm {
    var out: std.ArrayList(HeatTerm) = .empty;
    for (terms) |term| {
        var raw: usize = 0;
        var wt: i64 = 0;
        for (texts, weights) |txt, w| {
            const c = if (std.mem.eql(u8, term, "$")) countPlain(txt, term) else countWord(txt, term);
            raw += c;
            if (c > 0) wt += w;
        }
        if (raw > 0) try out.append(arena, .{ .term = term, .raw_mentions = raw, .score_weighted = wt });
    }
    std.mem.sort(HeatTerm, out.items, {}, cmpHeatDesc);
    return out.items;
}

pub fn run(gpa: Allocator, arena: Allocator, io: std.Io, log: *const cli.Logger, cfg: cli.Config) !void {
    _ = gpa;
    const cwd = std.Io.Dir.cwd();
    const ppath = try std.fmt.allocPrint(arena, "{s}/all_posts.json", .{cfg.data_dir});
    const cpath = try std.fmt.allocPrint(arena, "{s}/all_comments.json", .{cfg.data_dir});

    const pbytes = cwd.readFileAlloc(io, ppath, arena, .unlimited) catch |e| {
        log.log("cannot read {s}: {s}", .{ ppath, @errorName(e) });
        return;
    };
    const cbytes = cwd.readFileAlloc(io, cpath, arena, .unlimited) catch try arena.dupe(u8, "[]");

    const posts = try std.json.parseFromSliceLeaky([]model.Post, arena, pbytes, .{ .ignore_unknown_fields = true });
    const threads = try std.json.parseFromSliceLeaky([]model.CommentThread, arena, cbytes, .{ .ignore_unknown_fields = true });
    log.log("loaded {d} posts, {d} comment-threads", .{ posts.len, threads.len });

    var stop = try buildStopSet(arena);

    var subs: std.ArrayList([]const u8) = .empty;
    var seen = std.StringHashMap(void).init(arena);
    for (posts) |p| {
        const gop = try seen.getOrPut(p.subreddit);
        if (!gop.found_existing) try subs.append(arena, p.subreddit);
    }
    std.mem.sort([]const u8, subs.items, {}, strLess);

    var sub_counts: std.ArrayList(SubCount) = .empty;
    var sub_medians: std.ArrayList(SubMedian) = .empty;
    var sub_median_map = std.StringHashMap(f64).init(arena);
    for (subs.items) |s| {
        var scores: std.ArrayList(i64) = .empty;
        for (posts) |p| {
            if (std.mem.eql(u8, p.subreddit, s)) try scores.append(arena, p.score);
        }
        const m = try medianOf(arena, scores.items);
        try sub_counts.append(arena, .{ .sub = s, .count = scores.items.len });
        try sub_medians.append(arena, .{ .sub = s, .median = round1(m) });
        try sub_median_map.put(s, m);
    }

    var clusters: std.ArrayList(Cluster) = .empty;
    for (shapes) |shape| {
        var members: std.ArrayList(model.Post) = .empty;
        for (posts) |p| {
            if (p.title.len == 0) continue;
            const low = try lowerDup(arena, p.title);
            if (shape.f(p.title, low, p.post_type)) try members.append(arena, p);
        }
        if (members.items.len == 0) continue;
        std.mem.sort(model.Post, members.items, {}, cmpPostDesc);

        var mscores: std.ArrayList(i64) = .empty;
        for (members.items) |m| try mscores.append(arena, m.score);
        const mmed = try medianOf(arena, mscores.items);

        var examples: std.ArrayList(Example) = .empty;
        for (members.items[0..@min(5, members.items.len)]) |m| {
            try examples.append(arena, .{ .title = m.title, .score = m.score, .sub = m.subreddit });
        }

        var perf: std.ArrayList(SubPerf) = .empty;
        for (subs.items) |s| {
            var cs: std.ArrayList(i64) = .empty;
            for (members.items) |m| {
                if (std.mem.eql(u8, m.subreddit, s)) try cs.append(arena, m.score);
            }
            const base = sub_median_map.get(s) orelse 0;
            if (cs.items.len >= 3 and base > 0) {
                const cm = try medianOf(arena, cs.items);
                try perf.append(arena, .{ .sub = s, .ratio = round1(cm / base) });
            }
        }
        std.mem.sort(SubPerf, perf.items, {}, cmpPerfDesc);

        try clusters.append(arena, .{
            .name = shape.name,
            .count = members.items.len,
            .median_score = round1(mmed),
            .examples = examples.items,
            .overperformance_by_sub = perf.items,
        });
    }

    var title_texts: std.ArrayList([]const u8) = .empty;
    for (posts) |p| {
        if (p.title.len > 0) try title_texts.append(arena, p.title);
    }
    const ranked = try arena.dupe(model.Post, posts);
    std.mem.sort(model.Post, ranked, {}, cmpPostDesc);
    var top_titles: std.ArrayList([]const u8) = .empty;
    for (ranked[0..@min(300, ranked.len)]) |p| {
        if (p.title.len > 0) try top_titles.append(arena, p.title);
    }
    var comment_texts: std.ArrayList([]const u8) = .empty;
    for (threads) |t| {
        for (t.comments) |c| try comment_texts.append(arena, c.body);
    }

    var pains: std.ArrayList(Pain) = .empty;
    for (pain_themes) |theme| {
        var hits: std.ArrayList(model.Comment) = .empty;
        var hit_subs: std.ArrayList([]const u8) = .empty;
        for (threads) |t| {
            for (t.comments) |c| {
                const low = try lowerDup(arena, c.body);
                if (anyWord(low, theme.words)) {
                    try hits.append(arena, c);
                    try hit_subs.append(arena, t.subreddit);
                }
            }
        }
        if (hits.items.len == 0) continue;
        var order = try arena.alloc(usize, hits.items.len);
        for (order, 0..) |*o, idx| o.* = idx;
        const Ctx = struct {
            h: []const model.Comment,
            fn less(c: @This(), a: usize, b: usize) bool {
                return c.h[a].score > c.h[b].score;
            }
        };
        std.mem.sort(usize, order, Ctx{ .h = hits.items }, Ctx.less);
        var examples: std.ArrayList(PainExample) = .empty;
        for (order[0..@min(4, order.len)]) |idx| {
            const c = hits.items[idx];
            const body = if (c.body.len > 280) c.body[0..280] else c.body;
            try examples.append(arena, .{ .body = body, .score = c.score, .sub = hit_subs.items[idx] });
        }
        try pains.append(arena, .{ .theme = theme.name, .mentions = hits.items.len, .examples = examples.items });
    }
    std.mem.sort(Pain, pains.items, {}, cmpPainDesc);

    var fmt_winners: std.ArrayList(SubFormat) = .empty;
    for (subs.items) |s| {
        var stats: std.ArrayList(FormatStat) = .empty;
        for (post_types) |ty| {
            var scores: std.ArrayList(i64) = .empty;
            var sum: i64 = 0;
            for (posts) |p| {
                if (std.mem.eql(u8, p.subreddit, s) and std.mem.eql(u8, p.post_type, ty)) {
                    try scores.append(arena, p.score);
                    sum += p.score;
                }
            }
            if (scores.items.len == 0) continue;
            const mean: f64 = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(scores.items.len));
            try stats.append(arena, .{ .post_type = ty, .n = scores.items.len, .median = round1(try medianOf(arena, scores.items)), .mean = round1(mean) });
        }
        try fmt_winners.append(arena, .{ .sub = s, .types = stats.items });
    }
    var fmt_global: std.ArrayList(FormatStat) = .empty;
    for (post_types) |ty| {
        var scores: std.ArrayList(i64) = .empty;
        for (posts) |p| {
            if (std.mem.eql(u8, p.post_type, ty)) try scores.append(arena, p.score);
        }
        if (scores.items.len == 0) continue;
        try fmt_global.append(arena, .{ .post_type = ty, .n = scores.items.len, .median = round1(try medianOf(arena, scores.items)), .mean = 0 });
    }

    var heat_texts: std.ArrayList([]const u8) = .empty;
    var heat_weights: std.ArrayList(i64) = .empty;
    for (posts) |p| {
        const combined = try std.fmt.allocPrint(arena, "{s} {s}", .{ p.title, p.selftext_snippet });
        try heat_texts.append(arena, try lowerDup(arena, combined));
        const bonus = @min(@divTrunc(p.score, 100), 15);
        try heat_weights.append(arena, 1 + bonus);
    }

    var top_posts: std.ArrayList(TopPost) = .empty;
    for (ranked[0..@min(40, ranked.len)]) |p| {
        try top_posts.append(arena, .{ .title = p.title, .score = p.score, .sub = p.subreddit, .post_type = p.post_type, .comments = p.num_comments });
    }

    var total_comments: usize = 0;
    for (threads) |t| total_comments += t.comments.len;

    const analysis = Analysis{
        .totals = .{ .posts = posts.len, .comment_threads = threads.len, .comments = total_comments, .subreddits = subs.items },
        .per_sub_counts = sub_counts.items,
        .sub_median_score = sub_medians.items,
        .title_clusters = clusters.items,
        .hook_title_ngrams = try ngrams(arena, title_texts.items, &stop, 40, 4),
        .hook_title_ngrams_topposts = try ngrams(arena, top_titles.items, &stop, 30, 2),
        .hook_comment_ngrams = try ngrams(arena, comment_texts.items, &stop, 45, 5),
        .hook_title_unigrams = try unigrams(arena, title_texts.items, &stop, 50, 5),
        .hook_comment_unigrams = try unigrams(arena, comment_texts.items, &stop, 60, 5),
        .pain_points = pains.items,
        .format_winners = fmt_winners.items,
        .format_global = fmt_global.items,
        .topic_heatmap = .{
            .firms = try tally(arena, &firms, heat_texts.items, heat_weights.items),
            .languages = try tally(arena, &langs, heat_texts.items, heat_weights.items),
            .concepts = try tally(arena, &concepts, heat_texts.items, heat_weights.items),
            .comp_signals = try tally(arena, &comp_signals, heat_texts.items, heat_weights.items),
        },
        .top_posts_overall = top_posts.items,
    };

    const out_bytes = try std.json.Stringify.valueAlloc(arena, analysis, .{ .whitespace = .indent_2 });
    const apath = try std.fmt.allocPrint(arena, "{s}/analysis.json", .{cfg.data_dir});
    try cwd.writeFile(io, .{ .sub_path = apath, .data = out_bytes });
    try buildCsv(arena, io, cwd, try std.fmt.allocPrint(arena, "{s}/posts.csv", .{cfg.data_dir}), posts);

    log.log("wrote analysis.json + posts.csv", .{});
    log.log("==== QUICK SUMMARY ====", .{});
    log.log("posts={d} threads={d} comments={d}", .{ posts.len, threads.len, total_comments });
    var by_median = try arena.dupe(Cluster, clusters.items);
    std.mem.sort(Cluster, by_median, {}, cmpClusterMedianDesc);
    log.log("top clusters by median score:", .{});
    for (by_median[0..@min(6, by_median.len)]) |c| {
        log.log("  {s:<20} n={d:<5} median={d}", .{ c.name, c.count, c.median_score });
    }
}

fn csvStr(arena: Allocator, buf: *std.ArrayList(u8), s: []const u8) !void {
    var need = false;
    for (s) |c| {
        if (c == ',' or c == '"' or c == '\n' or c == '\r') {
            need = true;
            break;
        }
    }
    if (!need) {
        try buf.appendSlice(arena, s);
        return;
    }
    try buf.append(arena, '"');
    for (s) |c| {
        if (c == '"') {
            try buf.appendSlice(arena, "\"\"");
        } else if (c == '\n' or c == '\r') {
            try buf.append(arena, ' ');
        } else {
            try buf.append(arena, c);
        }
    }
    try buf.append(arena, '"');
}

fn csvNum(arena: Allocator, buf: *std.ArrayList(u8), n: i64) !void {
    const s = try std.fmt.allocPrint(arena, "{d}", .{n});
    try buf.appendSlice(arena, s);
}

fn buildCsv(arena: Allocator, io: std.Io, cwd: std.Io.Dir, path: []const u8, posts: []const model.Post) !void {
    var buf: std.ArrayList(u8) = .empty;
    try buf.appendSlice(arena, "subreddit,title,score,num_comments,post_type,created_date,url,selftext_snippet\n");
    for (posts) |p| {
        try csvStr(arena, &buf, p.subreddit);
        try buf.append(arena, ',');
        try csvStr(arena, &buf, p.title);
        try buf.append(arena, ',');
        try csvNum(arena, &buf, p.score);
        try buf.append(arena, ',');
        try csvNum(arena, &buf, p.num_comments);
        try buf.append(arena, ',');
        try csvStr(arena, &buf, p.post_type);
        try buf.append(arena, ',');
        try csvStr(arena, &buf, p.created_date);
        try buf.append(arena, ',');
        try csvStr(arena, &buf, p.url);
        try buf.append(arena, ',');
        const snip = if (p.selftext_snippet.len > 300) p.selftext_snippet[0..300] else p.selftext_snippet;
        try csvStr(arena, &buf, snip);
        try buf.append(arena, '\n');
    }
    try cwd.writeFile(io, .{ .sub_path = path, .data = buf.items });
}
