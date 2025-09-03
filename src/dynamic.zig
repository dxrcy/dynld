const std = @import("std");

const Handle = anyopaque;

// TODO: Add more error variants
const Error = error{DynamicLibError};

pub fn DynamicHandler(comptime Content: type) type {
    return struct {
        handle: *Handle,
        content: Content,

        pub fn open(path: [:0]const u8) Error!@This() {
            const handle = std.c.dlopen(path, std.c.RTLD{ .LAZY = true }) orelse {
                return Error.DynamicLibError;
            };
            return @This(){
                .handle = handle,
                .content = try loadContent(handle),
            };
        }

        pub fn close(self: @This()) Error!void {
            if (std.c.dlclose(self.handle) != 0) {
                return Error.DynamicLibError;
            }
        }

        fn loadContent(handle: *Handle) Error!Content {
            var content: Content = undefined;
            inline for (StructType(Content).fields) |field| {
                const opaq = std.c.dlsym(handle, field.name) orelse {
                    return Error.DynamicLibError;
                };
                @field(content, field.name) = convertValue(field.type, opaq);
            }
            return content;
        }
    };
}

fn convertValue(comptime T: type, opaq: *anyopaque) T {
    if (comptime isFnPointer(T)) {
        return @alignCast(@ptrCast(opaq));
    }
    // Whitelist types to prevent unexpected behaviour with strange types
    if (comptime isSupportedScalarType(T)) {
        const concrete: *T = @alignCast(@ptrCast(opaq));
        return concrete.*;
    }
    @compileError("unsupported dynamic content field type");
}

fn StructType(comptime T: type) std.builtin.Type.Struct {
    return switch (@typeInfo(T)) {
        .@"struct" => |structure| structure,
        else => @compileError("dynamic content type is not a struct"),
    };
}

fn isFnPointer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => true,
            else => false,
        },
        else => false,
    };
}

fn isSupportedScalarType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int => |int| int.bits == 8 or int.bits == 16 or int.bits == 32 or int.bits == 64,
        .float => |float| float.bits == 32 or float.bits == 64,
        else => false,
    };
}
