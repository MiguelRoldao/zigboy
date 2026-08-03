const Cart = @import("../cart.zig");
const Error = @import("../cart.zig").Error;
const VTable = @import("../cart.zig").VTable;

const dbg = @import("../dbg.zig");

const oob_read_val = 0xff;

const RomOnlyCart = @This();

rom: [0x8000]u8,

pub fn loadRom(self: *RomOnlyCart, rom: []const u8) Error!void {
    if (rom.len == self.rom.len) {
        @memcpy(&self.rom, rom);
    } else if (rom.len < self.rom.len) {
        dbg.log(
            .warning,
            "Loaded rom is smaller ({d} bytes) than expected ({d} bytes).",
            .{ rom.len, self.rom.len },
        );
        // copy the passed rom
        for (rom, 0..) |byte, i| {
            self.rom[i] = byte;
        }
        // Fill the remaining memory with 0xff
        for (rom.len..self.rom.len) |i| {
            self.rom[i] = 0xff;
        }
    } else {
        dbg.log(
            .user_error,
            "Loaded rom is bigger ({d} bytes) than expected ({d} bytes).",
            .{ rom.len, self.rom.len },
        );
        return Error.OutOfBounds;
    }
}

pub fn write(self: *RomOnlyCart, addr: u16, data: u8) void {

    // writing to a rom_only cart does absolutely nothing
    _ = self;
    dbg.log(
        .debug,
        "Wrote 0x{X:0>2} to a rom_only cart @0x{X:0>4}",
        .{ data, addr },
    );
}

pub fn read(self: *RomOnlyCart, addr: u16) u8 {
    if (addr < self.rom.len) {
        return self.rom[addr];
    } else {
        dbg.log(
            .debug,
            "Read from rom_only cart @0x{X:0>4}",
            .{addr},
        );
        return oob_read_val;
    }
}
