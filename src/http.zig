// ©AngelaMos | 2026
// http.zig

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Throttle = struct {
    base_ms: u64 = 2500,
    jitter_ms: u64 = 1500,
    max_retries: u32 = 6,
    backoff_start_ms: u64 = 5000,
    backoff_cap_ms: u64 = 120000,
};

pub const Fetcher = struct {
    gpa: Allocator,
    io: Io,
    client: std.http.Client,
    prng: std.Random.DefaultPrng,
    throttle: Throttle,
    ua: []const u8,
    req_count: usize,
    last_status: u16,

    pub fn init(gpa: Allocator, io: Io, throttle: Throttle, ua: []const u8) Fetcher {
        return .{
            .gpa = gpa,
            .io = io,
            .client = .{ .allocator = gpa, .io = io },
            .prng = std.Random.DefaultPrng.init(0x9E3779B97F4A7C15),
            .throttle = throttle,
            .ua = ua,
            .req_count = 0,
            .last_status = 0,
        };
    }

    pub fn deinit(self: *Fetcher) void {
        self.client.deinit();
    }

    fn sleepMs(self: *Fetcher, ms: u64) void {
        self.io.sleep(.{ .nanoseconds = @as(i96, @intCast(ms)) * std.time.ns_per_ms }, .awake) catch {};
    }

    fn politeWait(self: *Fetcher) void {
        const span: f64 = @floatFromInt(self.throttle.jitter_ms);
        const extra: u64 = @intFromFloat(self.prng.random().float(f64) * span);
        self.sleepMs(self.throttle.base_ms + extra);
    }

    pub fn get(self: *Fetcher, url: []const u8) !?[]u8 {
        var backoff = self.throttle.backoff_start_ms;
        var attempt: u32 = 1;
        while (attempt <= self.throttle.max_retries) : (attempt += 1) {
            self.politeWait();
            var body: std.Io.Writer.Allocating = .init(self.gpa);
            const res = self.client.fetch(.{
                .location = .{ .url = url },
                .method = .GET,
                .response_writer = &body.writer,
                .headers = .{ .user_agent = .{ .override = self.ua } },
            }) catch {
                body.deinit();
                self.sleepMs(backoff);
                backoff = @min(backoff * 2, self.throttle.backoff_cap_ms);
                continue;
            };
            self.req_count += 1;
            self.last_status = @intFromEnum(res.status);
            if (self.last_status == 200) {
                var arr = body.toArrayList();
                errdefer arr.deinit(self.gpa);
                return try arr.toOwnedSlice(self.gpa);
            }
            body.deinit();
            if (self.last_status == 403 or self.last_status == 429 or self.last_status >= 500) {
                self.sleepMs(backoff);
                backoff = @min(backoff * 2, self.throttle.backoff_cap_ms);
                continue;
            }
            return null;
        }
        return null;
    }
};
