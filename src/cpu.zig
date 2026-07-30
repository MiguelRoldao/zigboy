const std = @import("std");
const word = @import("util.zig").word;
const intcat = @import("util.zig").intcat;
const isCarryFromBit = @import("util.zig").intcat;
const Memory = @import("memory.zig").Memory;
const Registry = @import("registry.zig").Registry;

const builtin = @import("builtin");

pub fn db_only(val: anytype) ?@TypeOf(val) {
    return if (builtin.mode != .Debug) val else if (@TypeOf(val) == type) void else {};
}

pub const InstInfo: type = struct {
    cycles: u8,
    db_info: db_only([]const u8),
};

const Opcode = struct {
    data: u8 = 0x00,

    pub fn x(self: Opcode) u2 {
        return self.data >> 6 & 0b11;
    }

    pub fn y(self: Opcode) u3 {
        return self.data >> 3 & 0b111;
    }

    pub fn z(self: Opcode) u3 {
        return self.data & 0b111;
    }

    pub fn p(self: Opcode) u2 {
        return self.data >> 4 & 0b11;
    }

    pub fn q(self: Opcode) u1 {
        return self.data >> 3 & 0b1;
    }
};

const Machine = struct {
    rng: std.Random,
    regs: Registry,
    mem: Memory,
    op: Opcode,

    pub fn init(self: *Machine) void {
        self.rng = std.Random.DefaultPrng.init(0).random();
    }

    fn fetch(self: *Machine) u8 {
        const data = self.mem.read(self.regs.pc);
        self.regs.pc += 1;
        return data;
    }

    fn fetch2(self: *Machine) u16 {
        const hi = self.mem.read(self.regs.pc);
        const lo = self.mem.read(self.regs.pc + 1);
        self.regs.pc += 2;
        return intcat(hi, lo);
    }

    // === OPCODES === //
    // *** 8-BIT TRANSFER *** //
    fn op_ld_r_r(self: *Machine) InstInfo {
        const r1: u3 = self.op.y();
        const r2: u3 = self.op.y();
        self.regs.setR(r1, self.regs.getR(r2));
        return .{ .cycles = if (r1 == 6 or r2 == 6) 2 else 1 };
    }

    fn op_ld_r_n(self: *Machine) InstInfo {
        const r: u3 = self.op.y();
        self.set_r(r, self.fetch());
        return .{ .cycles = if (r == 6) 3 else 2 };
    }

    fn op_ld_a_bc(self: *Machine) InstInfo {
        self.regs.a = self.mem.read(intcat(self.regs.b, self.regs.c));
        return .{ .cycles = 2 };
    }

    fn op_ld_a_de(self: *Machine) InstInfo {
        self.regs.a = self.mem.read(intcat(self.regs.d, self.regs.e));
        return .{ .cycles = 2 };
    }

    fn op_ld_a_ff00_c(self: *Machine) InstInfo {
        self.regs.a = self.mem.read(0xFF00 + self.regs.c);
        return .{ .cycles = 2 };
    }

    fn op_ld_ff00_c_a(self: *Machine) InstInfo {
        self.mem.write(0xFF00 + self.regs.c, self.regs.a);
        return .{ .cycles = 2 };
    }

    fn op_ld_a_ff00_n(self: *Machine) InstInfo {
        self.regs.a = self.mem.read(0xFF00 + self.fetch());
        return .{ .cycles = 3 };
    }

    fn op_ld_ff00_n_a(self: *Machine) InstInfo {
        self.mem.write(0xFF00 + self.fetch(), self.regs.a);
        return .{ .cycles = 3 };
    }

    fn op_ld_nn_a(self: *Machine) InstInfo {
        const addr = self.fetch2();
        self.mem.write(addr, self.regs.a);
        return .{ .cycles = 4 };
    }

    fn op_ld_a_nn(self: *Machine) InstInfo {
        const addr = self.fetch2();
        self.regs.a = self.mem.read(addr);
        return .{ .cycles = 4 };
    }

    fn op_ld_a_hl_inc(self: *Machine) InstInfo {
        self.regs.a = self.mem.read(intcat(self.regs.h, self.regs.l));
        const res = @addWithOverflow(self.regs.l, 1);
        self.regs.h +%= res[1];
        self.regs.l = res[0];
        return .{ .cycles = 2 };
    }

    fn op_ld_a_hl_dec(self: *Machine) InstInfo {
        self.regs.a = self.mem.read(intcat(self.regs.h, self.regs.l));
        const res = @subWithOverflow(self.regs.l, 1);
        self.regs.h -%= res[1];
        self.regs.l = res[0];
        return .{ .cycles = 2 };
    }

    fn op_ld_bc_a(self: *Machine) InstInfo {
        self.mem.write(intcat(self.regs.b, self.regs.c), self.regs.a);
        return .{ .cycles = 2 };
    }

    fn op_ld_de_a(self: *Machine) InstInfo {
        self.mem.write(intcat(self.regs.d, self.regs.e), self.regs.a);
        return .{ .cycles = 2 };
    }

    fn op_ld_hl_inc_a(self: *Machine) InstInfo {
        self.mem.write(intcat(self.regs.h, self.regs.l), self.regs.a);
        const res = @addWithOverflow(self.regs.l, 1);
        self.regs.h +%= res[1];
        self.regs.l = res[0];
        return .{ .cycles = 2 };
    }

    fn op_ld_hl_dec_a(self: *Machine) InstInfo {
        self.mem.write(intcat(self.regs.h, self.regs.l), self.regs.a);
        const res = @subWithOverflow(self.regs.l, 1);
        self.regs.h -%= res[1];
        self.regs.l = res[0];
        return .{
            .cycles = 2,
        };
    }

    // *** 16-BIT TRANSFER *** //
    fn op_ld_rp_nn(self: *Machine) InstInfo {
        const addr = self.fetch2();
        self.a = self.mem.read(addr);
        return .{ .cycles = 4 };
    }

    fn op_ld_sp_hl(self: *Machine) InstInfo {
        self.regs.sp = intcat(self.regs.h, self.regs.l);
        return .{ .cycles = 2 };
    }

    fn op_push_rp2(self: *Machine) InstInfo {
        const rp2 = self.regs.getRp2(self.op.p());
        const hi: u8 = rp2 >> 8;
        const lo: u8 = rp2 | 0xff;
        self.mem.write(self.regs.sp - 1, hi);
        self.mem.write(self.regs.sp - 2, lo);
        self.regs.sp -= 2;
        return .{ .cycles = 4 };
    }

    fn op_pop_rp2(self: *Machine) InstInfo {
        const lo = self.mem.read(self.regs.sp);
        const hi = self.mem.read(self.regs.sp + 1);
        self.regs.setRp2(self.op.p, intcat(hi, lo));
        self.regs.sp += 2;
        return .{ .cycles = 4 };
    }

    fn op_ld_hl_sp_d(self: *Machine) InstInfo {
        const d: i8 = @bitCast(self.fetch());
        const sp: u16 = self.regs.sp;
        const res: u16 = @addWithOverflow(sp, d);
        self.regs.sp = res[0];
        self.regs.setZ(false);
        self.regs.setH(isCarryFromBit(sp, res[0], 12));
        self.regs.setN(false);
        self.regs.setC(res[1]);
        return .{ .cycles = 3 };
    }

    fn op_ld_nn_sp(self: *Machine) InstInfo {
        const nn = self.fetch2();
        self.mem.write2(nn, self.regs.sp);
        return .{ .cycles = 5 };
    }

    // *** 8-BIT ALU *** //
    // TODO: Keep going from here

    // TODO: Remove. This are the old chip8 opcodes
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

    pub fn step(self: *Machine) error{UnknownOp}!void {
        const hi = self.fetch();
        const lo = self.fetch();
        const op = Instruction{ .op = intcat(hi, lo) };
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
