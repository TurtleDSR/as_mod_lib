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

const token_delimiters = [_]u8{ ' ', '\t' };

/// **warning:**
///
/// Tokens returned will need to have their data individually
/// as well as freeing the list itself.
pub fn getTokens(data: []const u8, allocator: std.mem.Allocator) Error!std.ArrayList(Token) {
    var tokens: std.ArrayList(Token) = .empty;

    var token_str: std.ArrayList(u8) = .empty;
    defer token_str.clearAndFree(allocator);

    var token = Token{};

    var i: usize = 0;
    main_loop: while (i < data.len) : (i += 1) {
        const cur = data[i];
        
        if(cur == '\n' or cur == '\r') {
            if(token_str.items.len != 0) {
                token.keyword = lexertree.tree.getKeyword(token_str.items) catch ._text;
                token.data = allocator.dupe(u8, token_str.items) catch return Error.OutOfMemory;

                tokens.append(allocator, token) catch return Error.OutOfMemory;
                token = .{};
                token_str.clearRetainingCapacity();

                const newline_token: Token = .{.keyword = ._newline, .data = allocator.dupe(u8, "\n") catch return Error.OutOfMemory};
                tokens.append(allocator, newline_token) catch return Error.OutOfMemory;
            }

            if (cur == '\r' and i + 1 < data.len and data[i + 1] == '\n') {
                i += 1;
            }
            continue :main_loop;
        }

        inline for (token_delimiters) |d| {
            if (cur == d) {
                if (token_str.items.len != 0) {
                    token.keyword = lexertree.tree.getKeyword(token_str.items) catch ._text;
                    token.data = allocator.dupe(u8, token_str.items) catch return Error.OutOfMemory;

                    tokens.append(allocator, token) catch return Error.OutOfMemory;
                    token = .{};
                    token_str.clearRetainingCapacity();
                }
                continue :main_loop;
            }
        }

        token_str.append(allocator, cur) catch return Error.OutOfMemory;

        if (std.mem.eql(u8, token_str.items, "@//")) {
            token.keyword = .comment;
            token.data = allocator.dupe(u8, token_str.items) catch return Error.OutOfMemory;

            tokens.append(allocator, token) catch return Error.OutOfMemory;
            token = .{};
            token_str.clearRetainingCapacity();
            continue :main_loop;
        }
    }

    return tokens;
}
