const std = @import("std");
const common = @import("../common.zig");
const lexer = @import("lexer.zig");

const BUILDER: LexerTreeBuilder = blk: {
    var builder = LexerTreeBuilder{};

    builder.addKeyword("@open", common.keyword.open);
    builder.addKeyword("@import", common.keyword.import);
    builder.addKeyword("@patch", common.keyword.patch);
    builder.addKeyword("@add", common.keyword.add);
    builder.addKeyword("@end", common.keyword.end);
    builder.addKeyword("@//", common.keyword.comment);

    break :blk builder;
};

pub const tree = LexerTree{ .nodes = BUILDER.nodes[0..BUILDER.node_count] };

pub const LexerTree = struct {
    nodes: []const LexerNode,

    pub fn getKeyword(self: LexerTree, key: []const u8) lexer.LexerError!common.keyword {
        var idx: u32 = 0;

        for (key) |char| {
            const next_idx = self.nodes[idx].children[char];
            if (next_idx != NO_CHILD) {
                idx = next_idx;
            } else {
                return lexer.LexerError.UnknownKeyword;
            }
        }

        return self.nodes[idx].keyword orelse lexer.LexerError.UnknownKeyword;
    }
};

const LexerTreeBuilder = struct {
    const MAX_NODES = 256;

    nodes: [MAX_NODES]LexerNode = @splat(.{}),
    node_count: u8 = 1, // Node 0 is the root

    pub fn getRoot(self: *LexerTreeBuilder) *LexerNode {
        return &self.nodes[0];
    }

    pub fn addKeyword(comptime self: *LexerTreeBuilder, comptime key: []const u8, comptime keyword: common.keyword) void {
        var node = self.getRoot();

        for (key) |char| {
            if (node.children[char] == NO_CHILD) {
                if (self.node_count >= MAX_NODES) {
                    @compileError("LexerTree Node Pool Capacity Exceeded!");
                }
                const new_node_index = self.node_count;
                self.node_count += 1;

                node.children[char] = new_node_index;
            }

            node = &self.nodes[node.children[char]];
        }

        node.keyword = keyword;
    }
};

const NO_CHILD: u8 = std.math.maxInt(u8);
const LexerNode = struct {
    keyword: ?common.keyword = null,
    children: [256]u8 = @splat(NO_CHILD),
};
