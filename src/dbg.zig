const std = @import("std");

const dbg = @This();

const LogType = enum {
    user_error,
    warning,
    debug,
};

pub fn log(comptime log_type: LogType, comptime fmt: []const u8, args: anytype) void {
    //const buf: [fmt.len + 1]u8 = comptime blk: {
    //    var out: [fmt.len + 1]u8 = undefined;
    //    for (fmt, 0..) |byte, i| out[i] = byte;
    //    out[out.len - 1] = '\n';
    //    break :blk out;
    //};
    const new_fmt = std.fmt.comptimePrint("LOG[{t}]: {s}\n", .{ log_type, fmt });
    std.debug.print(new_fmt, args);
}

test "dbg_log" {
    dbg.log(.warning, "{s} world.", .{"hello"});
}
