const std = @import("std");

pub fn word(hi: u8, lo: u8) u16 {
    return @as(u16, hi) << 8 | lo;
}

fn assertUnsignedInt(comptime T: type) void {
    if ((@typeInfo(T) != .int) or (@typeInfo(T).int.signedness != .unsigned)) {
        @compileError(@typeName(T) ++ " is not an unsigned integer");
    }
}

fn IntcatType(comptime A: anytype, comptime B: anytype) type {
    comptime {
        assertUnsignedInt(A);
        assertUnsignedInt(B);
    }

    const T = @Int(.unsigned, @bitSizeOf(A) + @bitSizeOf(B));

    return T;
}

pub fn intcat(a: anytype, b: anytype) IntcatType(@TypeOf(a), @TypeOf(b)) {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    const Ret = IntcatType(A, B);

    return (@as(Ret, a) << @bitSizeOf(B)) | b;
}

pub fn lowByte(val: u16) u8 {
    return @truncate(val);
}

test "word ok" {
    const a: u8 = 0x45;
    const b: u8 = 0xf6;
    const c = word(a, b);
    try std.testing.expect(@TypeOf(c) == u16);
    try std.testing.expect(c == 0x45f6);
}

test "lowByte ok" {
    const a: u16 = 0x4567;
    const c = lowByte(a);
    try std.testing.expect(@TypeOf(c) == u8);
    try std.testing.expect(c == 0x67);
}

test "intcat ok" {
    const a: u8 = 0x2f;
    const b: u14 = 0x1535;
    const c = intcat(a, b);
    try std.testing.expect(@TypeOf(c) == u22);
    try std.testing.expect(c == (@as(u22, a) << 14) | b);
}
