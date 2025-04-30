pub fn word(hi: u8, lo: u8) u16 {
    return @as(u16, hi) << 8 | @as(u16, lo);
}

pub fn low_byte(val: u16) u8 {
    return @truncate(val);
}
