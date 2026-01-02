const std = @import("std");
const assert = std.debug.assert;
const Type = std.builtin.Type;
const CallingConvention = std.builtin.CallingConvention;

pub fn FieldFn(comptime T: type) type {
    var func = @typeInfo(T).@"fn";
    assert(func.calling_convention == .auto);
    func.calling_convention = .c;

    const field = *const @Type(Type{ .@"fn" = func });
    checkSymbolField(field);
    return field;
}

pub fn DynLib(comptime T: type) type {
    checkSymbolsStruct(T);

    return struct {
        const Self = @This();

        handle: std.DynLib,
        symbols: T,

        pub fn load(path: []const u8) !Self {
            var handle = try std.DynLib.open(path);
            const symbols = try loadFieldSymbols(T, &handle);
            return Self{
                .handle = handle,
                .symbols = symbols,
            };
        }

        pub fn close(self: *Self) void {
            self.handle.close();
        }
    };
}

fn checkSymbolsStruct(comptime T: type) void {
    const strct = @typeInfo(T).@"struct";
    comptime assert(strct.layout == .auto);
    comptime assert(strct.backing_integer == null);
    comptime assert(strct.decls.len == 0);
    comptime assert(!strct.is_tuple);

    inline for (strct.fields) |field| {
        comptime assert(!field.is_comptime);
        checkSymbolField(field.type);
    }
}

fn checkSymbolField(comptime T: type) void {
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

fn loadFieldSymbols(comptime T: type, handle: *std.DynLib) !T {
    checkSymbolsStruct(T);

    var content: T = undefined;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        @field(content, field.name) = try loadSymbol(
            field.type,
            field.name,
            field.defaultValue(),
            handle,
        );
    }
    return content;
}

fn loadSymbol(
    comptime T: type,
    comptime name: [:0]const u8,
    comptime default: ?T,
    handle: *std.DynLib,
) !T {
    checkSymbolField(T);

    if (handle.lookup(SymbolPtr(T), name)) |symbol| {
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
