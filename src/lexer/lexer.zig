const std = @import("std");
const common = @import("../common.zig");

const lexertree = @import("lexertree.zig");

const Token = @import("token.zig").Token;
const Keyword = common.Keyword;

pub const tree = lexertree.tree;

pub const Error = error{
    UnknownKeyword,
    OutOfMemory,
};

const token_delimiters = [_]u8{
    ' ',
    '\t',
    '\n'
};

//dont forget to free returned tokens
pub fn getTokens(data: []const u8, allocator: std.mem.Allocator) Error!std.ArrayList(Token) {
    var tokens: std.ArrayList(Token) = .empty;

    var token_buf: [32]u8 = @splat('_');
    var token_len: u5 = 0;

    var token = Token{};
    main_loop: for(data) |cur| {
        inline for(token_delimiters) |d| {
            if(cur == d) {
                if(token_len != 0) {
                    token.keyword = lexertree.tree.getKeyword(token_buf[0..token_len]) catch ._text;
                    token.data = allocator.dupe(u8, token_buf[0..token_len]) catch return Error.OutOfMemory;

                    tokens.append(allocator, token) catch return Error.OutOfMemory;
                    token = .{};
                    token_len = 0;
                }
                continue :main_loop;
            }
        }

        token_buf[token_len] = cur;
        token_len += 1;

        if(std.mem.eql(u8, token_buf[0..token_len], "@//")) {
            token.keyword = .comment;
            token.data = allocator.dupe(u8, token_buf[0..token_len]) catch return Error.OutOfMemory;

            tokens.append(allocator, token) catch return Error.OutOfMemory;
            token = .{};
            token_len = 0;
            continue :main_loop;
        }

        //check for max length, we can assert no valid keyword reaches max token length
        //so it's okay to split it into multiple tokens
        if(token_len == 31) {
            token.keyword = ._text;
            token.data = allocator.dupe(u8, token_buf[0..token_len]) catch return Error.OutOfMemory;

            tokens.append(allocator, token) catch return Error.OutOfMemory;
            token = .{};
            token_len = 0;
            continue :main_loop;
        }
    }

    return tokens;
}