const std = @import("std");

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    const path = args.next() orelse {
        std.debug.print("missing argument\n", .{});
        return error.MissingArgument;
    };

    var lib = try std.DynLib.open(path);
    defer lib.close();

    const foo = lib.lookup(*const fn (f32) f32, "foo") orelse {
        return error.NotFound;
    };
    const bar = lib.lookup(*const fn (u32) u32, "bar") orelse {
        return error.NotFound;
    };

    const foo_result = foo(45.0);
    std.debug.print("foo result: {}\n", .{foo_result});

    const bar_result = bar(45);
    std.debug.print("bar result: {}\n", .{bar_result});
}
