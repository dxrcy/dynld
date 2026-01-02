const std = @import("std");
const assert = std.debug.assert;

const CALLING_CONVENTION = std.builtin.CallingConvention.c;

pub fn FieldFn(comptime T: type) type {
    var func = @typeInfo(T).@"fn";
    assert(func.calling_convention == .auto);
    func.calling_convention = CALLING_CONVENTION;

    const field = *const @Type(.{ .@"fn" = func });
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

/// Currently very conservative in which types are supported.
fn checkSymbolsStruct(comptime T: type) void {
    const strct = @typeInfo(T).@"struct";

    // TODO: These can surely be relaxed
    comptime assert(strct.layout == .auto);
    comptime assert(strct.backing_integer == null);
    comptime assert(strct.decls.len == 0);
    comptime assert(!strct.is_tuple);

    inline for (strct.fields) |field| {
        comptime assert(!field.is_comptime);
        checkSymbolField(field.type);
    }
}

/// Currently very conservative in which types are supported.
fn checkSymbolField(comptime T: type) void {
    switch (@typeInfo(T)) {
        // I don't think it is possible or sensible to support these.
        .type,
        .void,
        .noreturn,
        .comptime_float,
        .comptime_int,
        .undefined,
        .null,
        .error_set,
        .@"fn",
        .@"opaque",
        .frame,
        .@"anyframe",
        .enum_literal,
        => unreachable,

        // These may be supportable? Some with difficulty, I am sure.
        .array,
        .@"struct",
        .optional,
        .@"enum",
        .error_union,
        .@"union",
        .vector,
        => unreachable,

        // Trivially copyable.
        // `usize` and isize` *are* sensible since the calling convention is
        // already platform-dependant.
        .bool,
        .int,
        .float,
        => {},

        .pointer => |pointer| {
            switch (@typeInfo(pointer.child)) {
                .@"fn" => |func| {
                    // TODO: Some of these may be relaxed?
                    comptime assert(!func.is_generic);
                    comptime assert(!func.is_var_args);
                    comptime assert(func.calling_convention.eql(CALLING_CONVENTION));
                    // Redundant: Only `null` if function is generic
                    comptime assert(func.return_type != null);

                    inline for (func.params) |param| {
                        // TODO: Some of these may be relaxed?
                        comptime assert(!param.is_generic);
                        comptime assert(!param.is_noalias);
                    }
                },

                // TODO:
                else => unreachable,
            }
        },
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
    return if (@typeInfo(T) == .pointer)
        T
    else
        *const T;
}

fn fromSymbolPtr(comptime T: type, value: SymbolPtr(T)) T {
    return if (@typeInfo(T) == .pointer)
        value
    else
        value.*;
}
