const std = @import("std");
const common = @import("../common.zig");

const Mod = common.Mod;

pub const Error = error{
    OutOfMemory,
    ItemNotFound,
};

pub const ModPool = struct {
    keys: std.ArrayList([]const u8),
    nodes: std.ArrayList(Node),
    
    /// a pool containing no mods.
    pub const empty = ModPool{
        .keys = .empty,
        .nodes = .empty,
    };

    /// adds a mod to the internal pool.
    /// 
    /// **Note**
    /// 
    /// will likely allocate memory.
    pub fn addMod(self: *ModPool, allocator: std.mem.Allocator, mod: Mod) Error!void {
        var node_index: usize = 0;
        if(self.nodes.items.len == 0) {
            self.nodes.append(allocator, .{}) catch return Error.OutOfMemory;
        }

        const key = mod.properties.id;

        for(key) |char| {
            if(self.nodes.items[node_index].children[char] == NO_CHILD) {
                self.nodes.append(allocator, Node{}) catch return Error.OutOfMemory;
                self.nodes.items[node_index].children[char] = self.nodes.items.len - 1;
            }

            node_index = self.nodes.items[node_index].children[char];
        }

        self.nodes.items[node_index].mod = mod;
        self.keys.append(allocator, mod.properties.id) catch return Error.OutOfMemory;
    }

    /// finds a mod by indexing its dependency string.
    pub fn findMod(self: *ModPool, key: []const u8) Error!Mod {
        var node_index: usize = 0;
        if(self.nodes.items.len == 0) {
            return Error.ItemNotFound;
        }

        for(key) |char| {
            const cur = self.nodes.items[node_index];

            if(cur.children[char] == NO_CHILD) return Error.ItemNotFound;
            node_index = cur.children[char];
        }

        if(self.nodes.items[node_index].mod) |m| {
            return m;
        }

        return Error.ItemNotFound;
    }

    /// purges the pool of all mods and keys.
    pub fn purge(self: *ModPool) void {
        self.keys.clearRetainingCapacity();
        self.nodes.clearRetainingCapacity();
    }

    /// purges the pool and frees list memory.
    pub fn destroy(self: *ModPool, allocator: std.mem.Allocator) void {
        self.keys.clearAndFree(allocator);
        self.nodes.clearAndFree(allocator);
    }
};

const NO_CHILD: usize = std.math.maxInt(usize);
const Node = struct {
    children: [256]usize = @splat(NO_CHILD),
    mod: ?Mod = null,
};