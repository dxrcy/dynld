const std = @import("std");

export const BAR: f64 = 4.1;

export fn foo(x: f64) f64 {
    return x + 6.7;
}

export fn baz(x: [*:0]u8) void {
    x[1] += 1;
    // x.* += 3;
}
