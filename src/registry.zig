const std = @import("std");
//const Memory = @import("memory.zig").Memory;
const Memory = u8;
const word = @import("util.zig").word;

pub const Registry = struct {
    a: u8 = undefined,
    b: u8 = undefined,
    c: u8 = undefined,
    d: u8 = undefined,
    e: u8 = undefined,
    h: u8 = undefined,
    l: u8 = undefined,
    f: u8 = undefined,

    sp: u16 = undefined,

    memory: ?*Memory = undefined,

    pub fn getR(self: *Registry, r: u3) u8 {
        return switch (r) {
            0 => self.b,
            1 => self.c,
            2 => self.d,
            3 => self.e,
            4 => self.h,
            5 => self.l,
            6 => 0, //self.memory.read(word(self.h, self.l)),
            7 => self.a,
        };
    }

    pub fn setR(self: *Registry, r: u3, val: u8) void {
        switch (r) {
            0 => self.b = val,
            1 => self.c = val,
            2 => self.d = val,
            3 => self.e = val,
            4 => self.h = val,
            5 => self.l = val,
            6 => 0, //self.memory.write(word(self.h, self.l), val),
            7 => self.a = val,
        }
    }

    pub fn getRp(self: *Registry, rp: u2) u16 {
        return switch (rp) {
            0 => word(self.b, self.c),
            1 => word(self.d, self.e),
            2 => word(self.h, self.l),
            3 => self.sp,
        };
    }

    pub fn setRp(self: *Registry, rp: u2, val: u16) void {
        const hi: u8 = @truncate(val >> 8);
        const lo: u8 = @truncate(val & 0xff);
        switch (rp) {
            0 => {
                self.b = hi;
                self.c = lo;
            },
            1 => {
                self.d = hi;
                self.e = lo;
            },
            2 => {
                self.h = hi;
                self.l = lo;
            },
            3 => self.sp = val,
        }
    }

    pub fn getRp2(self: *Registry, rp2: u2) u16 {
        return switch (rp2) {
            0 => word(self.b, self.c),
            1 => word(self.d, self.e),
            2 => word(self.h, self.l),
            3 => word(self.a, self.f),
        };
    }

    pub fn setRp2(self: *Registry, rp2: u2, val: u16) void {
        const hi: u8 = @truncate(val >> 8);
        const lo: u8 = @truncate(val & 0xff);
        switch (rp2) {
            0 => {
                self.b = hi;
                self.c = lo;
            },
            1 => {
                self.d = hi;
                self.e = lo;
            },
            2 => {
                self.h = hi;
                self.l = lo;
            },
            3 => {
                self.a = hi;
                self.f = lo;
            },
        }
    }

    pub fn getCc(self: *Registry, cc: u2) bool {
        return switch (cc) {
            0 => ~self.get_z(),
            1 => self.get_z(),
            2 => ~self.get_c(),
            3 => self.get_c(),
        };
    }

    pub fn getZ(self: *Registry) bool {
        return self.f & 0b10000000 != 0;
    }

    pub fn getN(self: *Registry) bool {
        return self.f & 0b01000000 != 0;
    }

    pub fn getH(self: *Registry) bool {
        return self.f & 0b00100000 != 0;
    }

    pub fn getC(self: *Registry) bool {
        return self.f & 0b00010000 != 0;
    }

    pub fn setZ(self: *Registry, val: bool) void {
        if (val) {
            self.f |= 0b10000000;
        } else {
            self.f &= 0b01111111;
        }
    }

    pub fn setN(self: *Registry, val: bool) void {
        if (val) {
            self.f |= 0b01000000;
        } else {
            self.f &= 0b10111111;
        }
    }

    pub fn setH(self: *Registry, val: bool) void {
        if (val) {
            self.f |= 0b00100000;
        } else {
            self.f &= 0b11011111;
        }
    }

    pub fn setC(self: *Registry, val: bool) void {
        if (val) {
            self.f |= 0b00010000;
        } else {
            self.f &= 0b11101111;
        }
    }
};

test "Registry set ok" {
    var r: Registry = .{
        .a = 0x00,
        .b = 0x00,
        .c = 0x00,
        .d = 0x00,
        .e = 0x00,
        .h = 0x00,
        .l = 0x00,
        .f = 0x00,
        .sp = 0x0000,
        .memory = null,
    };

    const expected: Registry = .{
        .a = 0x00,
        .b = 0x00,
        .c = 0x00,
        .d = 0x12,
        .e = 0x34,
        .h = 0x56,
        .l = 0x78,
        .f = 0b00010000,
        .sp = 0x9abc,
        .memory = null,
    };

    r.setC(true);
    r.setRp(1, 0x1234);
    r.setRp(3, 0x9abc);
    r.setRp2(2, 0x5678);

    std.debug.print(
        "Actual:\n\ta: ${x:02}, b: ${x:02}, c: ${x:02}, d: ${x:02}, e: ${x:02}, h: ${x:02}, l: ${x:02}, f: ${x:02}, sp: ${x:02}\n",
        .{ r.a, r.b, r.c, r.d, r.e, r.h, r.l, r.f, r.sp },
    );

    std.debug.print(
        "Expected:\n\ta: ${x:02}, b: ${x:02}, c: ${x:02}, d: ${x:02}, e: ${x:02}, h: ${x:02}, l: ${x:02}, f: ${x:02}, sp: ${x:02}\n",
        .{ expected.a, expected.b, expected.c, expected.d, expected.e, expected.h, expected.l, expected.f, expected.sp },
    );

    try std.testing.expect(std.meta.eql(r, expected));
}

test "Registry get ok" {
    var expected: Registry = .{
        .a = 0x00,
        .b = 0x12,
        .c = 0x34,
        .d = 0x56,
        .e = 0x78,
        .h = 0x00,
        .l = 0x00,
        .f = 0b11000000,
        .sp = 0xbeef,
        .memory = null,
    };

    var f: u8 = 0;
    f += if (expected.getC()) 0b00010000 else 0;
    f += if (expected.getH()) 0b00100000 else 0;
    f += if (expected.getN()) 0b01000000 else 0;
    f += if (expected.getZ()) 0b10000000 else 0;

    const r: Registry = .{
        .a = expected.getR(7),
        .b = expected.getR(0),
        .c = expected.getR(1),
        .d = expected.getR(2),
        .e = expected.getR(3),
        .h = expected.getR(4),
        .l = expected.getR(5),
        .f = f,
        .sp = expected.getRp(3),
        .memory = null,
    };

    std.debug.print(
        "Actual:\n\ta: ${x:02}, b: ${x:02}, c: ${x:02}, d: ${x:02}, e: ${x:02}, h: ${x:02}, l: ${x:02}, f: ${x:02}, sp: ${x:02}\n",
        .{ r.a, r.b, r.c, r.d, r.e, r.h, r.l, r.f, r.sp },
    );

    std.debug.print(
        "Expected:\n\ta: ${x:02}, b: ${x:02}, c: ${x:02}, d: ${x:02}, e: ${x:02}, h: ${x:02}, l: ${x:02}, f: ${x:02}, sp: ${x:02}\n",
        .{ expected.a, expected.b, expected.c, expected.d, expected.e, expected.h, expected.l, expected.f, expected.sp },
    );

    try std.testing.expect(std.meta.eql(r, expected));
}
