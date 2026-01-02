const std = @import("std");
const assert = std.debug.assert;
const DynLib = std.DynLib;
const Type = std.builtin.Type;
const CallingConvention = std.builtin.CallingConvention;

pub fn main() !void {
    const path = "./libexample.so";

    var lib = try Lib(Example).load(path);
    defer lib.close();

    inline for (std.meta.fields(@TypeOf(lib.interface))) |field| {
        std.debug.print("field {s}: {} = {any}\n", .{
            field.name,
            field.type,
            @field(lib.interface, field.name),
        });
    }

    std.debug.print("pi: {}\n", .{lib.interface.PI});
    std.debug.print("e: {}\n", .{lib.interface.E});

    const foo_result = lib.interface.foo(45.0);
    std.debug.print("foo result: {}\n", .{foo_result});

    const bar_result = lib.interface.bar(45);
    std.debug.print("bar result: {}\n", .{bar_result});

    const string = "abcdef";
    const baz_result = lib.interface.baz(@ptrCast(string), string.len);
    std.debug.print("baz result: {}\n", .{baz_result});
}

const Example = struct {
    PI: f64,
    E: f64 = 2.71828,
    foo: FieldFn(fn (f32) f32),
    bar: FieldFn(fn (u32) u32) = barDefault,
    baz: FieldFn(fn (*const u8, len: usize) void),
};

fn FieldFn(comptime T: type) type {
    var func = @typeInfo(T).@"fn";
    assert(func.calling_convention == .auto);
    func.calling_convention = .c;

    const field = *const @Type(Type{ .@"fn" = func });
    checkInterfaceField(field);
    return field;
}

fn barDefault(x: u32) callconv(.c) u32 {
    std.debug.print("barDefault: {}\n", .{x});
    return x + 20;
}

pub fn Lib(comptime T: type) type {
    checkInterface(T);

    return struct {
        const Self = @This();

        dynlib: DynLib,
        interface: T,

        pub fn load(path: []const u8) !Self {
            var dynlib = try DynLib.open(path);
            const interface = try loadFieldSymbols(T, &dynlib);
            return Self{
                .dynlib = dynlib,
                .interface = interface,
            };
        }

        pub fn close(self: *Self) void {
            self.dynlib.close();
        }
    };
}

fn checkInterface(comptime T: type) void {
    const strct = @typeInfo(T).@"struct";
    comptime assert(strct.layout == .auto);
    comptime assert(strct.backing_integer == null);
    comptime assert(strct.decls.len == 0);
    comptime assert(!strct.is_tuple);

    inline for (strct.fields) |field| {
        comptime assert(!field.is_comptime);
        checkInterfaceField(field.type);
    }
}

fn checkInterfaceField(comptime T: type) void {
    switch (@typeInfo(T)) {
        .@"fn" => |func| {
            comptime assert(!func.is_generic);
            comptime assert(!func.is_var_args);
            comptime assert(func.calling_convention.eql(CallingConvention.c));
            comptime assert(func.return_type != null);
            inline for (func.params) |param| {
                comptime assert(!param.is_generic);
                comptime assert(!param.is_noalias);
            }
        },

        else => {},
    }
}

fn loadFieldSymbols(comptime T: type, dynlib: *DynLib) !T {
    checkInterface(T);

    var content: T = undefined;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        @field(content, field.name) = try loadSymbol(
            field.type,
            field.name,
            field.defaultValue(),
            dynlib,
        );
    }
    return content;
}

fn loadSymbol(
    comptime T: type,
    comptime name: [:0]const u8,
    comptime default: ?T,
    dynlib: *DynLib,
) !T {
    checkInterfaceField(T);

    if (dynlib.lookup(SymbolPtr(T), name)) |symbol| {
        return fromSymbolPtr(T, symbol);
    }
    return default orelse
        error.SymbolNotFound;
}

fn SymbolPtr(comptime T: type) type {
    if (unwrapFnPtr(T)) |_| {
        return T;
    }
    return *const T;
}

fn fromSymbolPtr(comptime T: type, value: SymbolPtr(T)) T {
    if (unwrapFnPtr(T)) |_| {
        return value;
    }
    return value.*;
}

fn unwrapFnPtr(comptime T: type) ?type {
    switch (@typeInfo(T)) {
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => {
                return pointer.child;
            },
            else => {},
        },
        else => {},
    }
    return null;
}
