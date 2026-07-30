// TODO: implement Cart type
const Cart = @import("cart.zig").Cart;
const MbcNone = @import("cart.zig").MbcNone;

pub const ier_addr = 0xffff;
pub const hram_addr = 0xff80;
pub const reserved1_addr = 0xff4c;
pub const io_addr = 0xff00;
pub const reserved0_addr = 0xfea0;
pub const oam_addr = 0xfe00;
pub const iram_echo_addr = 0xe000;
pub const iram_addr = 0xc000;
pub const eram_addr = 0xa000;
pub const vram_addr = 0x8000;
pub const rom_addr = 0x0000;

pub const Memory = struct {
    cart: Cart = undefined,
    vram: [0x2000]u8 = undefined,
    iram: [0x2000]u8 = undefined,
    oam: [0xa0]u8 = undefined,
    io: [0x4c]u8 = undefined,
    hram: [0x7f]u8 = undefined,
    ier: u8 = undefined,

    pub fn init(self: *Memory) void {
        self.cart = null;
        self.vram = [_]u8{0} ** self.vram.len;
        self.iram = [_]u8{0} ** self.iram.len;
        self.oam = [_]u8{0} ** self.oam.len;
        self.io = [_]u8{0} ** self.io.len;
        self.hram = [_]u8{0} ** self.hram.len;
        self.ier = 0;
    }

    pub fn loadCart(self: *Memory, cart: *Cart) void {
        self.cart = cart;
    }

    pub fn write(self: *Memory, addr: u16, data: u8) void {
        // TODO: IO behaviour
        if (ier_addr == addr) {
            self.ier = data;
        } else if (hram_addr <= addr) {
            self.hram[addr - hram_addr] = data;
        } else if (reserved1_addr <= addr) {
            // do nothing
        } else if (io_addr <= addr) {
            self.io[addr - io_addr] = data;
        } else if (reserved0_addr <= addr) {
            // do nothing
        } else if (oam_addr <= addr) {
            self.oam[addr - oam_addr] = data;
        } else if (iram_echo_addr <= addr) {
            self.iram[addr - iram_echo_addr] = data;
        } else if (iram_addr <= addr) {
            self.iram[addr - iram_addr] = data;
        } else if (eram_addr <= addr) {
            // TODO: cart_write(self.pst_cart, addr, data);
        } else if (vram_addr <= addr) {
            self.vram[addr - vram_addr] = data;
        } else {
            // TODO: cart_write(self.pst_cart, addr, data);
        }
    }

    pub fn read(self: *Memory, addr: u16) u8 {
        // TODO: IO behaviour
        var data: u8 = undefined;
        if (ier_addr == addr) {
            data = self.ier;
        } else if (hram_addr <= addr) {
            data = self.hram[addr - hram_addr];
        } else if (reserved1_addr <= addr) {
            // do nothing
        } else if (io_addr <= addr) {
            data = self.io[addr - io_addr];
        } else if (reserved0_addr <= addr) {
            // do nothing
        } else if (oam_addr <= addr) {
            data = self.oam[addr - oam_addr];
        } else if (iram_echo_addr <= addr) {
            data = self.iram[addr - iram_echo_addr];
        } else if (iram_addr <= addr) {
            data = self.iram[addr - iram_addr];
        } else if (eram_addr <= addr) {
            // TODO: cart_write(self.pst_cart, addr, data);
        } else if (vram_addr <= addr) {
            data = self.vram[addr - vram_addr];
        } else {
            // TODO: cart_write(self.pst_cart, addr, data);
        }
        return data;
    }

    pub fn write2(self: *Memory, addr: u16, data: u16) void {
        self.write(addr, @truncate(data & 0xff));
        self.write(addr + 1, @truncate(data >> 8));
    }
};

// ******* TESTS ******* //
const expectEqual = @import("std").testing.expectEqual;
const print = @import("std").debug.print;

test "first" {
    var mem = Memory{};
    mem.cart.mbc_none = MbcNone{};
    mem.init();
    mem.write(0x0000, 0x00);
    for (mem.vram, 0..) |byte, addr| {
        expectEqual(0, byte) catch |err| {
            _ = addr;
            //print("error at vram[{X:0>4}]\n", .{addr});
            return err;
        };
    }
}
