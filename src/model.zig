// ©AngelaMos | 2026
// model.zig

const std = @import("std");

pub const Post = struct {
    id: []const u8,
    subreddit: []const u8,
    timeframe: []const u8,
    title: []const u8,
    score: i64,
    num_comments: i64,
    post_type: []const u8,
    domain: []const u8,
    created_date: []const u8,
    timestamp_ms: ?i64,
    url: []const u8,
    permalink: []const u8,
    author: []const u8,
    nsfw: bool,
    selftext_snippet: []const u8,
};

pub const Comment = struct {
    id: []const u8,
    author: []const u8,
    score: i64,
    body: []const u8,
};

pub const CommentThread = struct {
    post_id: []const u8,
    subreddit: []const u8,
    title: []const u8,
    score: i64,
    permalink: []const u8,
    selftext: []const u8,
    comments: []const Comment,
};
