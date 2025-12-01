const std = @import("std");

const DynamicHandler = @import("dynamic.zig").DynamicHandler;

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    const path = args.next() orelse {
        std.debug.print("missing argument\n", .{});
        return error.MissingArgument;
    };

    const handler = try DynamicHandler(Example).open(path);
    defer handler.close() catch unreachable;
    const lib = handler.content;

    std.debug.print("{d:.4}\n", .{lib.BAR});
    std.debug.print("{d:.4}\n", .{lib.foo(10.0)});

    var x: [10]u8 = undefined;
    std.mem.copyForwards(u8, &x, "abcdef");
    lib.baz(&x);
    std.debug.print("{s}\n", .{x});
}

const Example = struct {
    BAR: f64,
    foo: *const fn (a: f64) f64,
    baz: *const fn ([]u8) void,
};
