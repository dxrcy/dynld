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

    const foo = lib.lookup(*const fn (f64) f64, "foo") orelse {
        return error.NotFound;
    };

    const result = foo(123.4);
    std.debug.print("{}\n", .{result});

    const baz = lib.lookup(*const fn ([]u8) void, "baz") orelse {
        return error.NotFound;
    };

    const string = "abcdefghij";
    var buffer: [10]u8 = undefined;
    @memcpy(buffer[0..string.len], string);
    const slice = buffer[0..string.len];

    std.debug.print("{s}\n", .{slice});
    baz(slice);
    std.debug.print("{s}\n", .{slice});
}

const Example = struct {
    BAR: f64,
    foo: *const fn (a: f64) f64,
    baz: *const fn ([]u8) void,
};
