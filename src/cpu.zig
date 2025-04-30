const std = @import("std");
const word = @import("util.zig").word;

// TODO:
pub const Memory = struct {};

pub const Cycles = u8;

const Opcode = struct {
    data: u8 = 0x00,

    pub fn x(self: *Opcode) u2 {
        return self.data >> 6 & 0b11;
    }

    pub fn y(self: *Opcode) u3 {
        return self.data >> 3 & 0b111;
    }

    pub fn z(self: *Opcode) u3 {
        return self.data & 0b111;
    }

    pub fn p(self: *Opcode) u2 {
        return self.data >> 4 & 0b11;
    }

    pub fn q(self: *Opcode) u1 {
        return self.data >> 3 & 0b1;
    }
};

pub const Registry = struct {
    a: u8 = undefined,
    f: u8 = undefined,
    b: u8 = undefined,
    c: u8 = undefined,
    d: u8 = undefined,
    e: u8 = undefined,
    h: u8 = undefined,
    l: u8 = undefined,

    pc: u16 = undefined,
    sp: u16 = undefined,

    memory: *Memory = undefined,

    vram: [64 * 32]u1 = undefined,
    regs: [16]u8 = undefined,
    I: u16 = 0,
    sound_timer: u8 = 0,
    delay_timer: u8 = 0,
    stack: [0x100]u16 = undefined,

    keyboard: [16]bool = undefined,

    op: Instruction = undefined,

    rng: std.Random = undefined,

    pub fn get_r(self: *Registry, r: u3) u8 {
        return switch (r) {
            0 => self.b,
            1 => self.c,
            2 => self.d,
            3 => self.e,
            4 => self.h,
            5 => self.l,
            6 => self.memory.read(word(self.h, self.l)),
            7 => self.a,
        };
    }

    pub fn set_r(self: *Registry, r: u3, val: u8) void {
        switch (r) {
            0 => self.b = val,
            1 => self.c = val,
            2 => self.d = val,
            3 => self.e = val,
            4 => self.h = val,
            5 => self.l = val,
            6 => self.memory.write(word(self.h, self.l), val),
            7 => self.a = val,
        }
    }

    pub fn get_rp(self: *Registry, rp: u2) u16 {
        return switch (rp) {
            0 => word(self.b, self.c),
            1 => word(self.d, self.e),
            2 => word(self.h, self.l),
            3 => self.sp,
        };
    }

    pub fn set_rp(self: *Registry, rp: u2, val: u16) void {
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

    pub fn get_rp2(self: *Registry, rp2: u2) u16 {
        return switch (rp2) {
            0 => word(self.b, self.c),
            1 => word(self.d, self.e),
            2 => word(self.h, self.l),
            3 => word(self.a, self.f),
        };
    }

    pub fn set_rp2(self: *Registry, rp2: u2, val: u16) void {
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

    pub fn get_cc(self: *Registry, cc: u2) bool {
        return switch (cc) {
            0 => ~self.get_z(),
            1 => self.get_z(),
            2 => ~self.get_c(),
            3 => self.get_c(),
        };
    }

    pub fn get_z(self: *Registry) bool {
        return self.f & 0b10000000 != 0;
    }

    pub fn get_n(self: *Registry) bool {
        return self.f & 0b01000000 != 0;
    }

    pub fn get_h(self: *Registry) bool {
        return self.f & 0b00100000 != 0;
    }

    pub fn get_c(self: *Registry) bool {
        return self.f & 0b00010000 != 0;
    }

    pub fn set_z(self: *Registry, val: bool) void {
        if (val) {
            self.f |= 0b10000000;
        } else {
            self.f &= ~0b10000000;
        }
    }

    pub fn set_n(self: *Registry, val: bool) void {
        if (val) {
            self.f |= 0b01000000;
        } else {
            self.f &= ~0b01000000;
        }
    }

    pub fn set_h(self: *Registry, val: bool) void {
        if (val) {
            self.f |= 0b00100000;
        } else {
            self.f &= ~0b00100000;
        }
    }

    pub fn set_c(self: *Registry, val: bool) void {
        if (val) {
            self.f |= 0b00010000;
        } else {
            self.f &= ~0b00010000;
        }
    }

    // TODO:
    pub fn init(self: *Machine) void {
        // initialize data
        @memset(&self.memory, 0);
        @memset(&self.vram, 0);
        @memset(&self.regs, 0);
        @memset(&self.stack, 0);
        @memset(&self.keyboard, false);

        // copy char prites to memory
        for (char_sprites, 0..) |char_sprite, i| {
            for (char_sprite, 0..) |sprite, j| {
                self.memory[i * char_sprite.len + j] = sprite;
            }
        }

        self.rng = std.Random.DefaultPrng.init(0).random();
    }

    // TODO:
    pub fn read(self: *Machine, addr: u16) u8 {
        return self.memory[addr % self.memory.len];
    }

    // TODO:
    pub fn write(self: *Machine, addr: u16, data: u8) void {
        self.memory[addr % self.memory.len] = data;
    }

    // TODO: make this untied to screen resolotion
    pub fn read_vram(self: *Machine, x: u8, y: u8) u1 {
        const pos = (x % 64) +% ((y % 32) *% 64);
        return self.vram[pos];
    }

    // TODO: make this untied to screen resolotion
    pub fn write_vram(self: *Machine, x: u8, y: u8, data: u1) void {
        const pos = (x % 64) +% ((y % 32) *% 64);
        self.vram[pos] = data;
    }

    // TODO: make this untied to screen resolotion
    pub fn write_vram_xor(self: *Machine, x: u8, y: u8, data: u1) void {
        const pos = (x % 64) +% ((y % 32) *% 64);
        self.vram[pos] ^= data;
    }

    // ***** OPCODES ***** //
    // -- 8-bit transfer - //
    fn op_ld_r_r(self: *Registry) Cycles {
        const r1: u3 = self.op.y();
        const r2: u3 = self.op.y();
        self.set_r(r1, self.get_r(r2));
        return if (r1 == 6 or r2 == 6) 2 else 1;
    }

    fn op_ld_r_n(self: *Registry) Cycles {
        const r: u3 = self.op.y();
        self.set_r(r, self.fetch());
        return if (r == 6) 3 else 2;
    }

    fn op_ld_a_bc(self: *Registry) Cycles {
        self.a = self.memory.read(word(self.b, self.c));
        return 2;
    }

    fn op_ld_a_de(self: *Registry) Cycles {
        self.a = self.memory.read(word(self.d, self.e));
        return 2;
    }

    fn op_ld_a_ff00_c(self: *Registry) Cycles {
        self.a = self.memory.read(0xFF00 + self.c);
        return 2;
    }

    fn op_ld_ff00_c_a(self: *Registry) Cycles {
        self.memory.write(0xFF00 + self.c, self.a);
        return 2;
    }

    fn op_ld_a_ff00_n(self: *Registry) Cycles {
        self.a = self.memory.read(0xFF00 + self.fetch());
        return 3;
    }

    fn op_ld_ff00_n_a(self: *Registry) Cycles {
        self.memory.write(0xFF00 + self.fetch(), self.a);
        return 3;
    }

    fn op_ld_nn_a(self: *Registry) Cycles {
        const addr = self.fetch16();
        self.memory.write(addr, self.a);
        return 4;
    }

    fn op_ld_a_nn(self: *Registry) Cycles {
        const addr = self.fetch16();
        self.a = self.memory.read(addr);
        return 4;
    }

    fn op_ld_a_hl_inc(self: *Registry) Cycles {
        self.a = self.memory.read(word(self.h, self.l));
        const res = @addWithOverflow(self.l, 1);
        self.h +%= res[1];
        self.l = res[0];
        return 2;
    }

    fn op_ld_a_hl_dec(self: *Registry) Cycles {
        self.a = self.memory.read(word(self.h, self.l));
        const res = @subWithOverflow(self.l, 1);
        self.h -%= res[1];
        self.l = res[0];
        return 2;
    }

    fn op_ld_bc_a(self: *Registry) Cycles {
        self.memory.write(word(self.b, self.c), self.a);
        return 2;
    }

    fn op_ld_de_a(self: *Registry) Cycles {
        self.memory.write(word(self.d, self.e), self.a);
        return 2;
    }

    fn op_ld_hl_inc_a(self: *Registry) Cycles {
        self.memory.write(word(self.h, self.l), self.a);
        const res = @addWithOverflow(self.l, 1);
        self.h +%= res[1];
        self.l = res[0];
        return 2;
    }

    fn op_ld_hl_dec_a(self: *Registry) Cycles {
        self.memory.write(word(self.h, self.l), self.a);
        const res = @subWithOverflow(self.l, 1);
        self.h -%= res[1];
        self.l = res[0];
        return 2;
    }

    // - 16-bit transfer - //
    fn op_ld_rp_nn(self: *Registry) Cycles {
        const addr = self.fetch16();
        self.a = self.memory.read(addr);
        return 4;
    }

    pub fn op_cls(self: *Machine) void {
        self.vram = [_]u1{0} ** self.vram.len;
    }

    pub fn op_ret(self: *Machine) void {
        self.sp -%= 1;
        self.pc = self.stack[self.sp];
    }

    pub fn op_jp(self: *Machine) void {
        self.pc = self.op.nnn();
    }

    pub fn op_call(self: *Machine) void {
        self.stack[self.sp] = self.pc;
        self.sp +%= 1;
        self.pc = self.op.nnn();
    }

    pub fn op_sek(self: *Machine) void {
        const r = self.op.x();
        const kk = self.op.kk();
        if (self.regs[r] == kk) {
            self.pc += 2;
        }
    }

    pub fn op_snek(self: *Machine) void {
        const r = self.op.x();
        const kk = self.op.kk();
        if (self.regs[r] != kk) {
            self.pc += 2;
        }
    }

    pub fn op_se(self: *Machine) void {
        const rx = self.op.x();
        const ry = self.op.y();
        if (self.regs[rx] == self.regs[ry]) {
            self.pc += 2;
        }
    }

    pub fn op_ldk(self: *Machine) void {
        const r = self.op.x();
        const kk = self.op.kk();
        self.regs[r] = kk;
    }

    pub fn op_addk(self: *Machine) void {
        const r = self.op.x();
        const kk = self.op.kk();
        const res = @addWithOverflow(self.regs[r], kk);
        self.regs[r] = res[0];
    }

    // 8xxx ALU ops

    pub fn op_ld(self: *Machine, rx: u4, ry: u4) void {
        self.regs[rx] = self.regs[ry];
    }

    pub fn op_or(self: *Machine, rx: u4, ry: u4) void {
        self.regs[rx] |= self.regs[ry];
    }

    pub fn op_and(self: *Machine, rx: u4, ry: u4) void {
        self.regs[rx] &= self.regs[ry];
    }

    pub fn op_xor(self: *Machine, rx: u4, ry: u4) void {
        self.regs[rx] ^= self.regs[ry];
    }

    pub fn op_add(self: *Machine, rx: u4, ry: u4) void {
        const res = @addWithOverflow(self.regs[rx], self.regs[ry]);
        self.regs[rx] = res[0];
        self.regs[0xf] = res[1];
    }

    pub fn op_sub(self: *Machine, rx: u4, ry: u4) void {
        const res = @subWithOverflow(self.regs[rx], self.regs[ry]);
        self.regs[rx] = res[0];
        self.regs[0xf] = ~res[1];
    }

    pub fn op_shr(self: *Machine, rx: u4, ry: u4) void {
        self.regs[0xf] = self.regs[rx] & 1;
        self.regs[rx] = self.regs[rx] >> 1;
        _ = ry;
    }

    pub fn op_subn(self: *Machine, rx: u4, ry: u4) void {
        const res = @subWithOverflow(self.regs[ry], self.regs[rx]);
        self.regs[rx] = res[0];
        self.regs[0xf] = ~res[1];
    }

    pub fn op_shl(self: *Machine, rx: u4, ry: u4) void {
        self.regs[0xf] = self.regs[rx] >> 7;
        self.regs[rx] = self.regs[rx] << 1;
        _ = ry;
    }

    pub fn op_sne(self: *Machine) void {
        const rx = self.op.x();
        const ry = self.op.y();
        if (self.regs[rx] != self.regs[ry]) {
            self.pc += 2;
        }
    }

    pub fn op_ldi(self: *Machine) void {
        self.I = self.op.nnn();
    }

    pub fn op_jpr(self: *Machine) void {
        const v0: u8 = self.regs[0];
        self.pc += v0;
    }

    pub fn op_rnd(self: *Machine) void {
        const num = self.rng.int(u8);
        const kk = self.op.kk();
        self.regs[self.op.x()] = num & kk;
    }

    pub fn op_drw(self: *Machine) void {
        var collision: u1 = 0;
        for (0..self.op.n()) |n| {
            const sprite = self.read(@truncate(self.I + n));
            for (0..8) |i| {
                const x: u8 = @truncate(self.op.x() + i);
                const y: u8 = @truncate(self.op.y() + n);
                const pixel: u1 = @truncate((sprite >> @intCast(7 - i)) & 1);
                collision |= ~(pixel ^ self.read_vram(x, y));
                self.write_vram_xor(x, y, pixel);
            }
        }
    }

    pub fn op_skp(self: *Machine) void {
        const rx: u4 = @truncate(self.regs[self.op.x()]);
        if (self.keyboard[rx]) {
            self.pc += 2;
        }
    }

    pub fn op_sknp(self: *Machine) void {
        const rx: u4 = @truncate(self.regs[self.op.x()]);
        if (!self.keyboard[rx]) {
            self.pc += 2;
        }
    }

    pub fn op_ld_vx_dt(self: *Machine) void {
        self.regs[self.op.x()] = self.delay_timer;
    }

    pub fn op_ld_vx_k(self: *Machine) void {
        for (self.keyboard, 0..) |pressed, key| {
            if (pressed) {
                self.regs[self.op.x()] = @truncate(key);
                break;
            }
        } else {
            self.pc -= 2;
        }
    }

    pub fn op_ld_dt_vx(self: *Machine) void {
        self.delay_timer = self.regs[self.op.x()];
    }

    pub fn op_ld_st_vx(self: *Machine) void {
        self.sound_timer = self.regs[self.op.x()];
    }

    pub fn op_add_i_vx(self: *Machine) void {
        self.I +%= self.regs[self.op.x()];
    }

    pub fn op_ld_f_vx(self: *Machine) void {
        self.I = @truncate(char_sprites[0].len * self.regs[self.op.x()]);
    }

    // BCD representation
    pub fn op_ld_b_vx(self: *Machine) void {
        const vx: u8 = self.regs[self.op.x()];
        const ones: u8 = vx % 10;
        const tens: u8 = vx / 10 % 10;
        const hundreds: u8 = vx / 100 % 10;
        self.write(self.I, hundreds);
        self.write(self.I + 1, tens);
        self.write(self.I + 2, ones);
    }

    pub fn op_push(self: *Machine) void {
        for (0..self.op.x()) |i| {
            self.write(@truncate(self.I + i), self.regs[i]);
        }
    }

    pub fn op_pop(self: *Machine) void {
        for (0..self.op.x()) |i| {
            self.regs[i] = self.read(@truncate(self.I + i));
        }
    }

    pub fn fetch(self: *Registry) u8 {
        const data = self.read(self.pc);
        self.pc += 1;
        return data;
    }

    pub fn fetch16(self: *Registry) u16 {
        const hi = self.read(self.pc);
        const lo = self.read(self.pc + 1);
        self.pc += 2;
        return word(hi, lo);
    }

    pub fn step(self: *Machine) error{UnknownOp}!void {
        const hi = self.fetch();
        const lo = self.fetch();
        const op = Instruction{ .op = word(hi, lo) };
        self.op = op;

        switch (op.z()) {
            0x0 => switch (self.op.kk()) {
                0xE0 => self.op_cls(),
                0xEE => self.op_ret(),
                else => return error.UnknownOp,
            },
            0x1 => self.op_jp(),
            0x2 => self.op_call(),
            0x3 => self.op_sek(),
            0x4 => self.op_snek(),
            0x5 => self.op_se(),
            0x6 => self.op_ldk(),
            0x7 => self.op_addk(),
            0x8 => {
                const rx = self.op.x();
                const ry = self.op.y();
                switch (self.op.n()) {
                    0x0 => self.op_ld(rx, ry),
                    0x1 => self.op_or(rx, ry),
                    0x2 => self.op_and(rx, ry),
                    0x3 => self.op_xor(rx, ry),
                    0x4 => self.op_add(rx, ry),
                    0x5 => self.op_sub(rx, ry),
                    0x6 => self.op_shr(rx, ry),
                    0x7 => self.op_subn(rx, ry),
                    0xE => self.op_shl(rx, ry),
                    else => return error.UnknownOp,
                }
            },
            0x9 => self.op_sne(),
            0xA => self.op_ldi(),
            0xB => self.op_jpr(),
            0xC => self.op_rnd(),
            0xD => self.op_drw(),
            0xE => switch (self.op.kk()) {
                0x9E => self.op_skp(),
                0xA1 => self.op_sknp(),
                else => return error.UnknownOp,
            },
            0xF => switch (self.op.kk()) {
                0x07 => self.op_ld_vx_dt(),
                0x0A => self.op_ld_vx_k(),
                0x15 => self.op_ld_dt_vx(),
                0x18 => self.op_ld_st_vx(),
                0x1E => self.op_add_i_vx(),
                0x29 => self.op_ld_f_vx(),
                0x33 => self.op_ld_b_vx(),
                0x55 => self.op_push(),
                0x65 => self.op_pop(),
                else => return error.UnknownOp,
            },
        }
    }
};

pub const Instruction = struct {
    op: u16,

    pub fn nnn(self: Instruction) u12 {
        return @truncate(self.op);
    }

    pub fn kk(self: Instruction) u8 {
        return @truncate(self.op);
    }

    pub fn z(self: Instruction) u4 {
        return @truncate(self.op >> 12);
    }

    pub fn x(self: Instruction) u4 {
        return @truncate(self.op >> 8);
    }

    pub fn y(self: Instruction) u4 {
        return @truncate(self.op >> 4);
    }

    pub fn n(self: Instruction) u4 {
        return @truncate(self.op);
    }
};
