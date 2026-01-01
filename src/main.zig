const std = @import("std");
const assert = std.debug.assert;
const DynLib = std.DynLib;
const Type = std.builtin.Type;

pub fn main() !void {
    const path = "./libexample.so";

    var lib = try Lib(Example).load(path);
    defer lib.close();

    std.debug.print("pi: {}\n", .{lib.interface.PI.*});

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
    foo: fn (f32) f32,
    bar: fn (u32) u32,
    baz: fn (*const u8, len: usize) void,
};

pub fn Lib(comptime T: type) type {
    return struct {
        const Self = @This();

        dynlib: DynLib,
        interface: Interface(T),

        pub fn load(path: []const u8) !Self {
            var dynlib = try DynLib.open(path);
            const interface = try loadSymbols(Interface(T), &dynlib);
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
        comptime assert(field.default_value_ptr == null);
        comptime assert(!field.is_comptime);

        fields[i] = Type.StructField{
            .name = field.name,
            .type = InterfaceField(field.type),

            .default_value_ptr = null,
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
            comptime assert(func.calling_convention == .auto);
            comptime assert(func.return_type != null);

            return *const @Type(Type{
                .@"fn" = .{
                    .return_type = func.return_type,
                    .params = func.params,

                    .calling_convention = .c,
                    .is_generic = false,
                    .is_var_args = false,
                },
            });
        },

        else => return *const T,
    }
}

fn loadSymbols(comptime T: type, dynlib: *std.DynLib) !T {
    var content: T = undefined;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        @field(content, field.name) =
            dynlib.lookup(field.type, field.name) orelse {
                return error.SymbolNotFound;
            };
    }
    return content;
}
