const common = @import("../common.zig");
const Keyword = common.Keyword;

pub const Token = struct {
    keyword: Keyword = ._null,
    data: []const u8 = "",
};