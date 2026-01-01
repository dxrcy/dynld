const std = @import("std");

export const PI: f64 = 3.141592;

export fn foo(x: f32) f32 {
    std.debug.print("foo: {}\n", .{x});
    return x + 10.0;
}

export fn bar(x: u32) u32 {
    std.debug.print("bar: {}\n", .{x});
    return x + 10;
}

export fn baz(ptr: [*]const u8, len: usize) void {
    const string = ptr[0..len];
    std.debug.print("baz: {s}\n", .{string});
}
