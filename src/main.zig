const std = @import("std");
const assert = std.debug.assert;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

pub fn Get(comptime Value: type) type {
    return struct {
        ptr: *anyopaque,
        getFn: *const fn (ptr: *anyopaque) Value,

        const Self = @This();

        pub fn init(pointer: anytype, comptime getFn: fn (ptr: @TypeOf(pointer)) Value) Self {
            const Ptr = @TypeOf(pointer);
            assert(@typeInfo(Ptr) == .Pointer); // Must be a pointer
            assert(@typeInfo(Ptr).Pointer.size == .One); // Must be a single-item pointer
            const gen = struct {
                fn get(ptr: *anyopaque) Value {
                    const alignment = @typeInfo(Ptr).Pointer.alignment;
                    const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
                    return getFn(self);
                }
            };

            return .{
                .ptr = pointer,
                .getFn = gen.get,
            };
        }

        pub fn get(g: Get(Value)) Value {
            return g.getFn(g.ptr);
        }
    };
}

pub fn GetField(comptime Type: type, comptime Value: type, comptime field: []const u8, pointer: anytype) Get(Value) {
    const gen = struct {
        fn get(container: *Type) Value {
            return @field(container, field);
        }
    };

    return Get(Value).init(pointer, gen.get);
}

test "get" {
    const S = struct {
        a: u8,
        b: u32,
    };
    var s = S{ .a = 1, .b = 2 };
    const getA = GetField(S, u8, "a", &s);
    const getB = GetField(S, u32, "b", &s);

    try std.testing.expectEqual(@as(u8, 1), getA.get());
    try std.testing.expectEqual(@as(u32, 2), getB.get());
}

pub fn Set(comptime Value: type) type {
    return struct {
        ptr: *anyopaque,
        setFn: *const fn (ptr: *anyopaque, value: Value) void,

        const Self = @This();

        pub fn init(pointer: anytype, comptime setFn: fn (ptr: @TypeOf(pointer), value: Value) void) Self {
            const Ptr = @TypeOf(pointer);
            assert(@typeInfo(Ptr) == .Pointer); // Must be a pointer
            assert(@typeInfo(Ptr).Pointer.size == .One); // Must be a single-item pointer
            const gen = struct {
                fn set(ptr: *anyopaque, value: Value) void {
                    const alignment = @typeInfo(Ptr).Pointer.alignment;
                    const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
                    setFn(self, value);
                }
            };

            return .{
                .ptr = pointer,
                .setFn = gen.set,
            };
        }

        pub fn set(g: Set(Value), value: Value) void {
            g.setFn(g.ptr, value);
        }
    };
}

pub fn SetField(comptime Type: type, comptime Value: type, comptime field: []const u8, pointer: anytype) Set(Value) {
    const gen = struct {
        fn set(container: *Type, value: Value) void {
            @field(container, field) = value;
        }
    };

    return Set(Value).init(pointer, gen.set);
}

test "set" {
    const S = struct {
        a: u8,
        b: u32,
    };
    var s = S{ .a = 1, .b = 2 };
    const setA = SetField(S, u8, "a", &s);
    const setB = SetField(S, u32, "b", &s);

    setA.set(10);
    setB.set(20);

    try std.testing.expectEqual(@as(u8, 10), s.a);
    try std.testing.expectEqual(@as(u32, 20), s.b);
}

pub fn Lense(comptime Value: type) type {
    return struct {
        setter: Set(Value),
        getter: Get(Value),

        const Self = @This();

        pub fn init(s: Set(Value), g: Get(Value)) Self {
            return .{ .setter = s, .getter = g };
        }

        pub fn set(lense: Self, value: Value) void {
            lense.setter.set(value);
        }

        pub fn get(lense: Self) Value {
            return lense.getter.get();
        }
    };
}

pub fn LenseField(comptime Type: type, comptime Value: type, comptime field: []const u8, pointer: anytype) Lense(Value) {
    return Lense(Value).init(SetField(Type, Value, field, pointer), GetField(Type, Value, field, pointer));
}

test "lense" {
    const S = struct {
        a: u8,
        b: u32,
    };
    var s = S{ .a = 1, .b = 2 };

    const lenseA = LenseField(S, u8, "a", &s);
    const lenseB = LenseField(S, u32, "b", &s);

    lenseA.set(10);
    lenseB.set(20);

    try std.testing.expectEqual(@as(u8, 10), lenseA.get());
    try std.testing.expectEqual(@as(u32, 20), lenseB.get());
}
