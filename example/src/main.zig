const std = @import("std");

export fn foo(x: f32) f32 {
    std.debug.print("foo: {}\n", .{x});
    return x + 10.0;
}

export fn bar(x: u32) u32 {
    std.debug.print("bar: {}\n", .{x});
    return x + 10;
}
