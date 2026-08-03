const Cart = @This();
const RomOnlyCart = @import("cart_types/rom_only.zig");

const std = @import("std");
const print = std.debug.print;

userdata: ?*anyopaque,
vtable: *const VTable,

pub const CartridgeType = enum(u8) {
    rom_only = 0x0,
    mbc1_rom = 0x1,
    mbc1_rom_ram = 0x2,
    mbc1_rom_ram_bat = 0x3,
    mbc2_rom = 0x5,
    mbc2_rom_bat = 0x6,
    rom_ram = 0x8,
    rom_ram_bat = 0x9,
    mmm01_rom = 0xb,
    mmm01_rom_ram = 0xc,
    mmm01_rom_ram_bat = 0xd,
    mbc3_rom_bat_tim = 0xf,
    mbc3_rom_ram_bat_tim = 0x10,
    mbc3_rom = 0x11,
    mbc3_rom_ram = 0x12,
    mbc3_rom_ram_bat = 0x13,
    mbc5_rom = 0x19,
    mbc5_rom_ram = 0x1a,
    mbc5_rom_ram_bat = 0x1b,
    mbc5_rom_rum = 0x1c,
    mbc5_rom_ram_rum = 0x1d,
    mbc5_rom_ram_bat_rum = 0x1e,
    pocket_cam = 0x1f,
    bandai_tama5 = 0xfd,
    hudson_huc3 = 0xfe,
    hudson_huc1 = 0xff,
    _,
    // TODO: What about:
    //     - mbc7
    //     - m161
    //     - mbc1m
    //     - ems
    //     - bung
    //     - wisdom_tree
};

pub const addrCartridgeType: u16 = 0x0147;

pub const Error = error{
    OutOfBounds,
    UnknownMbc,
};

pub const VTable = struct {
    loadRom: *const fn (cart: ?*anyopaque, rom: []const u8) Error!void,
    write: *const fn (cart: ?*anyopaque, addr: u16, data: u8) void,
    read: *const fn (cart: ?*anyopaque, addr: u16) u8,
};

pub fn loadRom(cart: *Cart, rom: []const u8) Error!void {
    if (rom.len < 0x200) return Error.OutOfBounds;

    const mbc: CartridgeType = @enumFromInt(rom[addrCartridgeType]);
    switch (mbc) {
        .rom_only => {
            var s: RomOnlyCart = .{
                .rom = [_]u8{0x0} ** 0x8000,
            };
            cart.* = init(&s);
            cart.vtable.loadRom(cart.userdata, rom) catch |err| return err;
        },
        else => return Error.UnknownMbc,
    }
}

pub fn write(cart: *Cart, addr: u16, data: u8) void {
    cart.vtable.write(cart.userdata, addr, data);
}

pub fn read(cart: *Cart, addr: u16) u8 {
    return cart.vtable.read(cart.userdata, addr);
}

// empty cart implementation
pub const empty_cart: Cart = .{
    .userdata = null,
    .vtable = &.{
        .loadRom = emptyLoad,
        .write = emptyWrite,
        .read = emptyRead,
    },
};

fn emptyLoad(cart: ?*anyopaque, rom: []const u8) Error!void {
    _ = cart;
    _ = rom;
    return Error.OutOfBounds;
}

fn emptyWrite(cart: ?*anyopaque, addr: u16, data: u8) void {
    _ = cart;
    _ = addr;
    _ = data;
    return;
}

fn emptyRead(cart: ?*anyopaque, addr: u16) u8 {
    _ = cart;
    return @truncate(addr);
}

test "empty_cart" {
    const rom = [_]u8{0x04} ** 0x200;
    var c: Cart = .empty_cart;

    const err = c.loadRom(&rom);
    try std.testing.expect(err == Error.UnknownMbc);
}

/// Create all wrappers to transform ?*anyopaque into the specific cart type
fn init(ptr: anytype) Cart {
    if (@typeInfo(@TypeOf(ptr)) != .pointer) @compileError("Cart.init() must be called with a pointer to a cart");
    const CartType = @TypeOf(ptr.*);
    return .{
        .userdata = ptr,
        .vtable = &.{
            .loadRom = @ptrCast(&struct {
                pub fn f(cart: ?*anyopaque, rom: []const u8) Error!void {
                    const self: *CartType = @ptrCast(@alignCast(cart));
                    return CartType.loadRom(self, rom);
                }
            }.f),
            .write = @ptrCast(&struct {
                pub fn f(cart: ?*anyopaque, addr: u16, data: u8) void {
                    const self: *CartType = @ptrCast(@alignCast(cart));
                    CartType.write(self, addr, data);
                }
            }.f),
            .read = @ptrCast(&struct {
                pub fn f(cart: ?*anyopaque, addr: u16) u8 {
                    const self: *CartType = @ptrCast(@alignCast(cart));
                    return CartType.read(self, addr);
                }
            }.f),
        },
    };
}

test "rom_only_cart" {
    var c: Cart = .empty_cart;
    //var c: Cart = .{
    //    .userdata = &s,
    //    .vtable = &.{
    //        .loadRom = RomOnlyCart.loadRom,
    //        .write = RomOnlyCart.write,
    //        .read = RomOnlyCart.read,
    //    },
    //};
    const rom = [_]u8{ 0x1, 0x0 } ** 0x1000;

    const err: Error!void = c.loadRom(&rom);
    print("cart rom len: {any}\n", .{@as(*RomOnlyCart, @ptrCast(@alignCast(c.userdata))).rom.len});
    print("{!}\n", .{err});
    err catch try std.testing.expect(false);
    var val = c.read(0x0000);
    print("c.read(0x0000) == 0x{x}\n", .{val});
    try std.testing.expect(val == 1);
    c.write(0x0000, 0xAA);
    val = c.read(0x0000);
    print("c.read(0x0000) == 0x{x}\n", .{val});
    try std.testing.expect(val == 1);
}
