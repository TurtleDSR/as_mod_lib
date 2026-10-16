const std = @import("std");
const common = @import("../common.zig");
const modpool = @import("../pool/modpool.zig");
const scriptedit = @import("../parser/scriptedit.zig");

const parser = @import("../parser/parser.zig");
const injector = @import("../injector/injector.zig");

const zip = common.zip;

const InjectorError = common.InjectorError;
const ModFormat = common.ModFormat;
const Mod = common.Mod;

const ModPool = modpool.ModPool;

const ScriptEdit = scriptedit.ScriptEdit;

/// Handle for mod injection
pub const ModLib = struct {
    /// Path to the games script folder on disk. (<Steam_Common>/ItTakesTwo/Nuts/ for example)
    scripts_path: [:0]const u8,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _hazemod_mod_pool: ModPool = .empty,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _hazemod_mod_queue: std.PriorityQueue(Mod, void, orderMods) = .empty,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _hazemod_levels: std.array_hash_map.String(u8) = .empty,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _zip_mod_pool: std.ArrayList(Mod) = .empty,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _allocator: std.mem.Allocator,

    /// Initializes a ModLib handle.
    ///
    /// **Parameters:**
    ///
    /// *game_path* - path to the game directory.
    ///
    /// *allcoator* - allocator.
    ///
    /// **Returns:**
    ///
    /// Resulting ModLib handle.
    ///
    /// **Note**
    ///
    /// Do not forget to call deinit on the returned handle when finished.
    pub fn init(game_path: [:0]const u8, allocator: std.mem.Allocator) InjectorError!ModLib {
        const handle: ModLib = .{
            .scripts_path = std.fmt.allocPrintSentinel(allocator, "{s}/Scripts/", .{game_path}, 0) catch return InjectorError.OutOfMemory,
            ._allocator = allocator,
        };

        return handle;
    }

    /// Destroys a ModLib handle
    pub fn deinit(self: *ModLib) void {
        self._allocator.free(self.scripts_path);

        self._hazemod_mod_pool.destroy(self._allocator);
        self._hazemod_mod_queue.deinit(self._allocator);
        self._zip_mod_pool.deinit(self._allocator);
        self._hazemod_levels.deinit(self._allocator);
    }

    /// Queues the mod to the internal mod pool.
    /// Call installMods to install all the mods at once.
    ///
    /// **Parameters:**
    ///
    /// *mod* - mod handle to add to the pool.
    ///
    /// **Note:**
    ///
    /// May allocate memory.
    pub fn queueMod(self: *ModLib, mod: Mod) InjectorError!void {
        switch (mod.format) {
            ModFormat.ZIP => {
                self._zip_mod_pool.append(self._allocator, mod) catch return InjectorError.OutOfMemory;
            },
            ModFormat.HAZEMOD => {
                self._hazemod_mod_pool.addMod(self._allocator, mod) catch return InjectorError.OutOfMemory;
            },
        }
    }

    /// Installs all currently queued mods.
    ///
    /// **Note:**
    ///
    /// All zip mods will be installed first, in order of queue index.
    /// Dependecies for hazemod mods will be evaluated and respected.
    ///
    /// mod pool will be purged on installation success.
    pub fn installMods(self: *ModLib, io: std.Io) InjectorError!void {
        //install zip mods.
        //must be done sequentially since theres no dependency system.
        for (self._zip_mod_pool.items) |mod| {
            try self.installZipMod(mod);
        }

        if (self._hazemod_mod_pool.keys.items.len > 0) { //skip installing hazemods if they arent present
            self._hazemod_levels.clearRetainingCapacity();
            //order hazemod handles into queue.
            while (self._hazemod_mod_pool.keys.items.len > 0) {
                const key = self._hazemod_mod_pool.pop(0) catch return InjectorError.MissingDependency;
                _ = try self.orderModR(key);
            }

            var buf: [256]ScriptEdit = @splat(ScriptEdit{}); //256 should avoid wait time most of the time i think

            var level: u8 = 0;

            var thread_stop: std.atomic.Value(bool) = .init(false); //threads will stop when this is set true

            //use cores / 2 as our thread count
            //unless mod count is less than that, we use modcount
            const thread_count = @min(self._hazemod_mod_queue.items.len, (std.Thread.getCpuCount() catch return InjectorError.ThreadingError) / 2);
            var edit_queue: std.Io.Queue(ScriptEdit) = .init(&buf);

            var task_list: std.ArrayList(std.Io.Future(InjectorError!void)) = .empty;
            defer task_list.clearAndFree(self._allocator);

            for (0..thread_count) |i| {
                _ = i;
                var thread = std.Thread.spawn(.{ .allocator = self._allocator }, threadExecuteEdits, .{ io, &edit_queue, &thread_stop }) catch return InjectorError.ThreadingError;
                thread.detach();
            }

            while (self._hazemod_mod_queue.items.len > 0) : (level += 1) {
                while (self._hazemod_mod_queue.items.len > 0 and self._hazemod_mod_queue.peek().?.dependency_level == level) { //start all mods of the current level
                    if (self._hazemod_mod_queue.pop()) |m| {
                        const task: std.Io.Future(InjectorError!void) = io.async(workerStreamEdits, .{ m, &edit_queue, self._allocator });
                        task_list.append(self._allocator, task) catch return InjectorError.OutOfMemory;
                    } else {
                        return InjectorError.UnknownError;
                    }
                }

                for (task_list.items) |*t| { //await all tasks finished
                    try t.await(io);
                }

                task_list.clearRetainingCapacity();
            }
            thread_stop.store(true, .release);
        }

        self._hazemod_mod_pool.purge();
        self._zip_mod_pool.clearRetainingCapacity();
        self._hazemod_mod_queue.clearRetainingCapacity();
    }

    /// Installs a mod using the legacy zip format.
    ///
    /// **Params:**
    ///
    /// *mod* - mod handle to inject.
    fn installZipMod(self: *ModLib, mod: Mod) InjectorError!void {
        zip.extract(mod.path, self.scripts_path, null, null) catch |err| {
            switch (err) {
                zip.ZipError.FileNotFound => return InjectorError.FileNotFound,
                zip.ZipError.FileOpenFailure => return InjectorError.FileOpenFailure,
                zip.ZipError.FReadError => return InjectorError.FileReadError,
                zip.ZipError.FWriteError => return InjectorError.FileWriteError,
                else => return InjectorError.UnknownError,
            }
        };
    }

    fn orderModR(self: *ModLib, key: []const u8) InjectorError!u8 {
        const mod_index = self._hazemod_mod_pool.findMod(key) catch return InjectorError.MissingDependency;

        if (self._hazemod_mod_pool.nodes.items[mod_index].mod) |m| {
            var level: u8 = 0;

            //handle dependencies
            if (m.properties.dependencies) |deps| {
                for (deps) |dep| {
                    if (self._hazemod_levels.get(dep)) |lev| {
                        level = @max(level, lev + 1);
                        continue;
                    }

                    const lev = try self.orderModR(dep);
                    level = @max(level, lev + 1);
                }
            }

            //handle soft dependencies
            if (m.properties.soft_dependencies) |deps| {
                for (deps) |dep| {
                    if (self._hazemod_levels.get(dep)) |lev| {
                        level = @max(level, lev + 1);
                        continue;
                    }

                    const lev = self.orderModR(dep) catch {
                        continue;
                    }; //ignore error since dependency isnt required
                    level = @max(level, lev + 1);
                }
            }

            if (self._hazemod_mod_pool.nodes.items[mod_index].mod != null) {
                self._hazemod_mod_pool.nodes.items[mod_index].mod.?.dependency_level = level;
            }

            self._hazemod_mod_queue.push(self._allocator, m) catch return InjectorError.OutOfMemory;

            self._hazemod_mod_pool.removeKey(key);
            self._hazemod_levels.put(self._allocator, key, level) catch return InjectorError.OutOfMemory;

            return level;
        } else {
            return InjectorError.MissingDependency;
        }
    }
};

/// Used for ordering mods in the installation queue.
fn orderMods(context: void, a: Mod, b: Mod) std.math.Order {
    _ = context; //ignored

    if (a.dependency_level < b.dependency_level) {
        return std.math.Order.lt;
    } else if (a.dependency_level == b.dependency_level) {
        return std.math.Order.eq;
    } else {
        return std.math.Order.gt;
    }
}

/// Executes edits from the queue multithreaded
fn threadExecuteEdits(io: std.Io, queue: *std.Io.Queue(ScriptEdit), stop_condition: *std.atomic.Value(bool)) InjectorError!void {
    while (!stop_condition.load(.acquire)) {
        const edit = queue.getOne(io) catch return InjectorError.ThreadingError;
        try injector.executeEdit(edit, io);
    }
}

/// Streams edits to the queue to be executed multithreaded
fn workerStreamEdits(mod: Mod, queue: *std.Io.Queue(ScriptEdit), allocator: std.mem.Allocator) InjectorError!void {
    var z = zip.open(mod.path, zip.defaultCompressionLevel, 'r') catch return InjectorError.FileOpenFailure;
    {
        defer z.close();

        const entries = z.getEntryTotal() catch return InjectorError.FileReadError;

        for (0..entries) |i| {
            z.openEntryByIndex(i) catch return InjectorError.FileReadError;
            {
                defer z.closeEntry();

                const entry_name = z.getEntryName() catch return InjectorError.FileReadError;

                if (std.mem.eql(u8, std.Io.Dir.path.extension(entry_name), ".as")) { //check if file is .as
                    const contents = z.readEntry(allocator) catch return InjectorError.FileReadError;
                    defer allocator.free(contents);
                    try parser.streamEdits(contents, queue, allocator);
                }

                if (std.mem.eql(u8, std.Io.Dir.path.extension(entry_name), ".pak")) { //check if file is .pak
                    //unimplemented
                }
            }
        }
    }
}
