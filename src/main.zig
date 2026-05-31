// ©AngelaMos | 2026
// main.zig

const std = @import("std");
const cli = @import("cli.zig");
const scrape = @import("scrape.zig");
const analyze = @import("analyze.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);
    var logger = cli.Logger.init(io);
    const parsed = try cli.parseArgs(arena, args);

    switch (parsed.cmd) {
        .scrape => try scrape.run(gpa, arena, io, &logger, parsed.config),
        .analyze => try analyze.run(gpa, arena, io, &logger, parsed.config),
        .help => cli.printUsage(),
    }
}
