const print = @import("std").debug.print;

const CartridgeType = enum(u8) {
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

const addrCartridgeType: u16 = 0x0147;

pub const Cart = struct {
    mbc: CartridgeType,
    rom: []u8,
    ram: []u8,

    const Error = error{
        OutOfBounds,
        UnknownMbc,
    };

    pub fn loadRom(self: *Cart, rom: []u8) Error!void {
        if (rom.len < 0x200) return .OutOfBounds;

        self.mbc = @enumFromInt(rom[addrCartridgeType]);
        switch (self.mbc) {
            .rom_only => {
                self.rom = rom;
                self.ram = null;
            },
            else => return .UnkwnownMbc,
        }
    }

    pub fn write(self: *Cart, addr: u16, data: u8) Error!void {
        switch (self.mbc) {
            .rom_only => {
                _ = data;
                _ = addr;
            },
            else => {
                print("Don't know how to write to this cart type (0x{x})");
                return Error.UnknownMbc;
            },
        }
    }

    pub fn read(self: *Cart, addr: u16) u8 {
        return switch (self.mbc) {
            .rom_only => if (addr < self.rom.len) self.rom[addr] else 0x00,
            else => {
                print("Don't know how to read from this cart type (0x{x})", .{@intFromEnum(self.mbc)});
                return Error.UnknownMbc;
            },
        };
    }
};
