const std = @import("std");

const dynld = @import("dynld.zig");
const DynLib = dynld.DynLib;
const FieldFn = dynld.FieldFn;

pub fn main() !void {
    const path = "./libexample.so";

    var lib = try DynLib(Example).load(path);
    defer lib.close();

    std.debug.print("----\n", .{});
    inline for (std.meta.fields(@TypeOf(lib.symbols))) |field| {
        std.debug.print("field {s}: {} = {any}\n", .{
            field.name,
            field.type,
            @field(lib.symbols, field.name),
        });
    }

    std.debug.print("----\n", .{});
    std.debug.print("pi: {}\n", .{lib.symbols.PI});
    std.debug.print("e: {}\n", .{lib.symbols.E});

    std.debug.print("----\n", .{});
    const foo_result = lib.symbols.foo(45.0);
    std.debug.print("foo result: {}\n", .{foo_result});

    std.debug.print("----\n", .{});
    const bar_result = lib.symbols.bar(45);
    std.debug.print("bar result: {}\n", .{bar_result});

    std.debug.print("----\n", .{});
    const string = "abcdef";
    const baz_result = lib.symbols.baz(@ptrCast(string), string.len);
    std.debug.print("baz result: {}\n", .{baz_result});
}

const Example = struct {
    PI: f64,
    E: f64 = 2.71828,
    foo: FieldFn(fn (f32) f32),
    bar: FieldFn(fn (u32) u32) = barDefault,
    baz: FieldFn(fn (*const u8, len: usize) void),
};

fn barDefault(x: u32) callconv(.c) u32 {
    std.debug.print("barDefault: {}\n", .{x});
    return x + 20;
}
