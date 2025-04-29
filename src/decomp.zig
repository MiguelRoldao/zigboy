//! This module provides functionality for dissassembling chip-8 bytecode.

const std = @import("std");
const Instruction = @import("cpu.zig").Instruction;
const File = @import("std").fs.File;

const ByteClass = enum {
    undefined,
    op_hi,
    op_lo,
    var_jump,
};

const max_rom_size = 0x10000;

pub fn parseRom(f_rom: File, f_out: File) !void {
    const var_size = (try f_rom.stat()).size;
    var rom = [_]u8{undefined} ** max_rom_size;
    try f_rom.seekTo(0);
    _ = try f_rom.readAll(&rom);

    var classes = [_]ByteClass{.undefined} ** max_rom_size;

    var labeled = [_]bool{false} ** max_rom_size;
    labeled[0] = true;

    parseBranch(&rom, &classes, &labeled, @intCast(var_size), 0);

    // fix last byte
    if (classes[var_size - 1] == .op_hi) classes[var_size - 1] = .undefined;

    var n: u16 = 0;
    while (n < var_size) : (n += 1) {
        const addr = n + 0x0200;

        if (labeled[n]) try f_out.writer().print("\nlabel_0x{X:4>0}:\n", .{addr});

        switch (classes[n]) {
            .undefined => {
                var n_undef: u16 = 1;
                var n_temp = n;
                while (n_temp + 1 < var_size and classes[n_temp + 1] == .undefined and !labeled[n_temp + 1]) : (n_temp += 1) {
                    n_undef += 1;
                }
                const full_lines = n_undef / 8;
                const columns_last_line = n_undef & 8;

                for (0..full_lines) |_| {
                    try f_out.writer().print("\t.db 0x{X:2>0}, 0x{X:2>0}, 0x{X:2>0}, 0x{X:2>0}, 0x{X:2>0}, 0x{X:2>0}, 0x{X:2>0}, 0x{X:2>0}\n", .{ rom[n], rom[n + 1], rom[n + 2], rom[n + 3], rom[n + 4], rom[n + 5], rom[n + 6], rom[n + 7] });
                    n += 8;
                }
                if (columns_last_line > 0) {
                    try f_out.writer().print("\t.db 0x{X:2>0}", .{rom[n]});
                    for (1..columns_last_line) |i| {
                        try f_out.writer().print(", 0x{X:2>0}", .{rom[n + i]});
                    }
                    try f_out.writer().print("\n", .{});
                }
                n -= 1;
                // TODO: print up to 8 bytes per line
                //try f_out.writer().print("\t.db 0x{X:2>0}\n", .{rom[n]});
            },
            .op_hi => {
                const inst = Instruction{ .op = word(rom[n], rom[n + 1]) };
                try f_out.writer().print("\t", .{});
                try asmFromOp(inst, f_out);
                try f_out.writer().print("\n", .{});
                n += 1;
            },
            .var_jump => {
                const inst = Instruction{ .op = word(rom[n], rom[n + 1]) };
                try f_out.writer().print("\t", .{});
                try asmFromOp(inst, f_out);
                try f_out.writer().print("\n\t; after a variable jump it's impossible to tell where to branch\n\t; at compile time. Some instructions might be marked as data!\n", .{});
                n += 1;
            },
            else => {
                try f_out.writer().print("ERROR: Unexpected ByteClass.op_lo in address 0x{X:4>0}\nExiting...\n", .{addr});
                return error.UnexpectedOpHi;
            },
        }
    }
}

fn parseBranch(rom: [*]u8, classes: [*]ByteClass, labeled: [*]bool, len: u16, arg_n: u16) void {
    var n: u16 = arg_n;
    // label every address where a new branch is created
    labeled[n] = true;

    while (n < len) : (n += 2) {
        // only go further if byte is data or undefined
        if (classes[n] != .undefined) return;

        const hi = rom[n];
        const lo = rom[n + 1];
        const inst = Instruction{ .op = word(hi, lo) };

        // if byte is not part of an instruction don't go further
        if (!isInstKnown(inst)) return;

        // byte (and followed byte) form an instruction
        classes[n] = .op_hi;
        classes[n + 1] = .op_lo;

        // decide branching based on instruction
        switch (inst.z()) {
            // ret instruction -> end branch
            0x0 => if (inst.op == 0x00EE) return,
            // jp instruction -> goto address and label it
            0x1 => {
                n = inst.nnn() - 0x200;
                labeled[n] = true;
                n -= 2;
            },
            // call instruction -> branch to address and label it
            0x2 => {
                parseBranch(rom, classes, labeled, len, inst.nnn() - 0x200);
            },
            // skip (not) equals instructions -> branch to n+4 and label it
            0x3, 0x4, 0x5, 0x9 => {
                parseBranch(rom, classes, labeled, len, n + 4);
            },
            // skip if (not) keypress instructions -> branch to n+4 and label it
            0xE => switch (inst.kk()) {
                0x9E, 0xA1 => {
                    parseBranch(rom, classes, labeled, len, n + 4);
                },
                else => {},
            },
            // variable jump -> can't know where to jump. class it and end branch.
            0xB => {
                classes[n] = .var_jump;
                return;
            },
            else => {},
        }
    }
}

pub fn asmFromOp(inst: Instruction, out_file: File) !void {
    const writer = out_file.writer();
    switch (inst.z()) {
        0x0 => switch (inst.kk()) {
            0xE0 => try writer.print("cls", .{}),
            0xEE => try writer.print("ret", .{}),
            else => try writer.print("???(0x{X:4>0})", .{inst.op}),
        },
        0x1 => try writer.print("jp 0x{X:3>0}", .{inst.nnn()}),
        0x2 => try writer.print("call 0x{X:3>0}", .{inst.nnn()}),
        0x3 => try writer.print("se v{X}, 0x{X:2>0}", .{ inst.x(), inst.kk() }),
        0x4 => try writer.print("sne v{X}, 0x{X:2>0}", .{ inst.x(), inst.kk() }),
        0x5 => try writer.print("se v{X}, v{X}", .{ inst.x(), inst.y() }),
        0x6 => try writer.print("ld v{X}, 0x{X:2>0}", .{ inst.x(), inst.kk() }),
        0x7 => try writer.print("add v{X}, 0x{X:2>0}", .{ inst.x(), inst.kk() }),
        0x8 => switch (inst.n()) {
            0x0 => try writer.print("ld v{X}, v{X}", .{ inst.x(), inst.y() }),
            0x1 => try writer.print("or v{X}, v{X}", .{ inst.x(), inst.y() }),
            0x2 => try writer.print("and v{X}, v{X}", .{ inst.x(), inst.y() }),
            0x3 => try writer.print("xor v{X}, v{X}", .{ inst.x(), inst.y() }),
            0x4 => try writer.print("add v{X}, v{X}", .{ inst.x(), inst.y() }),
            0x5 => try writer.print("sub v{X}, v{X}", .{ inst.x(), inst.y() }),
            0x6 => try writer.print("shr v{X} {{, v{X}}}", .{ inst.x(), inst.y() }),
            0x7 => try writer.print("subn v{X}, v{X}", .{ inst.x(), inst.y() }),
            0xE => try writer.print("shl v{X} {{, v{X}}}", .{ inst.x(), inst.y() }),
            else => try writer.print("???(0x{X:4>0})", .{inst.op}),
        },
        0x9 => try writer.print("sne v{X}, v{X}", .{ inst.x(), inst.y() }),
        0xA => try writer.print("ld I 0x{X:3>0}", .{inst.nnn()}),
        0xB => try writer.print("jp v0, 0x{X:3>0}", .{inst.nnn()}),
        0xC => try writer.print("rnd v{X}, 0x{X:2>0}", .{ inst.x(), inst.kk() }),
        0xD => try writer.print("drw v{X}, v{X}, 0x{X}", .{ inst.x(), inst.y(), inst.n() }),
        0xE => switch (inst.kk()) {
            0x9E => try writer.print("skp v{X}", .{inst.x()}),
            0xA1 => try writer.print("sknp v{X}", .{inst.x()}),
            else => try writer.print("???(0x{X:4>0})", .{inst.op}),
        },
        0xF => switch (inst.kk()) {
            0x07 => try writer.print("ld v{X}, dt", .{inst.x()}),
            0x0A => try writer.print("ld v{X}, k", .{inst.x()}),
            0x15 => try writer.print("ld dt, v{X}", .{inst.x()}),
            0x18 => try writer.print("ld st, v{X}", .{inst.x()}),
            0x1E => try writer.print("add I, v{X}", .{inst.x()}),
            0x29 => try writer.print("spr v{X}", .{inst.x()}),
            0x33 => try writer.print("bcd v{X}", .{inst.x()}),
            0x55 => try writer.print("ld [I], v0..v{X}", .{inst.x()}),
            0x65 => try writer.print("ld v0..v{X}, [I]", .{inst.x()}),
            else => try writer.print("???(0x{X:4>0})", .{inst.op}),
        },
    }
}

fn isInstKnown(inst: Instruction) bool {
    switch (inst.z()) {
        0x0 => switch (inst.kk()) {
            0xE0 => return true,
            0xEE => return true,
            else => return false,
        },
        0x1...0x7 => return true,
        0x8 => switch (inst.n()) {
            0x0...0x7 => return true,
            0xE => return true,
            else => return false,
        },
        0x9...0xD => return true,
        0xE => switch (inst.kk()) {
            0x9E => return true,
            0xA1 => return true,
            else => return false,
        },
        0xF => switch (inst.kk()) {
            0x07 => return true,
            0x0A => return true,
            0x15 => return true,
            0x18 => return true,
            0x1E => return true,
            0x29 => return true,
            0x33 => return true,
            0x55 => return true,
            0x65 => return true,
            else => return false,
        },
    }
}

pub fn word(hi: u8, lo: u8) u16 {
    return @as(u16, hi) << 8 | @as(u16, lo);
}
