const std = @import("std");
const assert = std.debug.assert;
const DynLib = std.DynLib;
const Type = std.builtin.Type;
const CallingConvention = std.builtin.CallingConvention;

pub fn main() !void {
    const path = "./libexample.so";

    var lib = try Lib(Example).load(path);
    defer lib.close();

    std.debug.print("pi: {}\n", .{lib.interface.PI.*});
    std.debug.print("e: {}\n", .{lib.interface.E.*});

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
    foo: fn (f32) callconv(.c) f32,
    bar: fn (u32) callconv(.c) u32 = barDefault,
    baz: fn (*const u8, len: usize) callconv(.c) void,
};

fn barDefault(x: u32) callconv(.c) u32 {
    std.debug.print("barDefault: {}\n", .{x});
    return x + 20;
}

pub fn Lib(comptime T: type) type {
    return struct {
        const Self = @This();

        dynlib: DynLib,
        interface: Interface(T),

        pub fn load(path: []const u8) !Self {
            var dynlib = try DynLib.open(path);
            const interface = try loadFieldSymbols(Interface(T), &dynlib);
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

fn Interface(comptime T: type) type {
    const strct = @typeInfo(T).@"struct";
    comptime assert(strct.layout == .auto);
    comptime assert(strct.backing_integer == null);
    comptime assert(strct.decls.len == 0);
    comptime assert(!strct.is_tuple);

    var fields: [strct.fields.len]Type.StructField = undefined;
    inline for (strct.fields, 0..) |field, i| {
        comptime assert(!field.is_comptime);

        const default_value_ptr: ?*const InterfaceField(field.type) =
            if (field.defaultValue()) |default|
                &toInterfaceField(field.type, default)
            else
                null;

        const opaque_ptr: ?*const anyopaque = @ptrCast(default_value_ptr);

        fields[i] = Type.StructField{
            .name = field.name,
            .type = InterfaceField(field.type),
            .default_value_ptr = opaque_ptr,

            .is_comptime = false,
            .alignment = @alignOf(InterfaceField(field.type)),
        };
    }

    return @Type(Type{
        .@"struct" = .{
            .fields = &fields,

            .layout = .auto,
            .backing_integer = null,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

fn InterfaceField(comptime T: type) type {
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
    return *const T;
}

fn toInterfaceField(comptime T: type, comptime field: T) InterfaceField(T) {
    return &field;
}

fn loadFieldSymbols(comptime T: type, dynlib: *DynLib) !T {
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
    return dynlib.lookup(T, name) orelse
        default orelse
        error.SymbolNotFound;
}
