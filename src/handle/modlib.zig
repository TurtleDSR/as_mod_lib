const std = @import("std");
const common = @import("../common.zig");
const modpool = @import("../pool/modpool.zig");

const zip = common.zip;

const InjectorError = common.InjectorError;
const ModFormat = common.ModFormat;
const Mod = common.Mod;

const ModPool = modpool.ModPool;

/// Handle for mod injection
pub const ModLib = struct {
    /// Path to the games script folder on disk.
    scripts_path: [:0]const u8,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _asmod_mod_pool: ModPool = .empty,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _asmod_mod_queue: std.PriorityQueue(Mod, void, order_mods) = .empty,
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
    /// *scriptsPath* - path to the Scripts/ directory of the game.
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
    pub fn init(scriptsPath: [:0]const u8, allocator: std.mem.Allocator) ModLib {
        const handle: ModLib = .{
            .scripts_path = scriptsPath,
            ._allocator = allocator,
        };

        return handle;
    }

    /// Destroys a ModLib handle
    pub fn deinit(self: *ModLib) void {
        self._asmod_mod_pool.destroy(self._allocator);
        self._asmod_mod_queue.deinit(self._allocator);
        self._zip_mod_pool.deinit(self._allocator);
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
            ModFormat.ASMOD => {
                self._asmod_mod_pool.addMod(self._allocator, mod) catch return InjectorError.OutOfMemory;
            }
        }
    }

    /// Installs all currently queued mods.
    ///
    /// **Note:**
    ///
    /// All zip mods will be installed first, in order of queue index.
    /// Dependecies for asmod mods will be evaluated and respected.
    ///
    /// mod pool will be purged on installation success.
    pub fn installMods(self: *ModLib, io: std.Io) InjectorError!void {
        _ = io;

        //install zip mods.
        //must be done sequentially since theres no dependency system.
        for(self._zip_mod_pool.items) |mod| {
            try self.installZipMod(mod);
        }

        //order asmod handles into queue.
        while(self._asmod_mod_pool.keys.items.len > 0) {
            const key = self._asmod_mod_pool.pop(0) catch return InjectorError.MissingDependency;
            _ = try self.handle_mod(key);
        }

        self._asmod_mod_pool.purge();
        self._zip_mod_pool.clearRetainingCapacity();
        self._asmod_mod_queue.clearRetainingCapacity();
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

    fn handle_mod(self: *ModLib, key: []const u8) InjectorError!u8 {
        const mod_index = self._asmod_mod_pool.findMod(key) catch return InjectorError.MissingDependency;

        if(self._asmod_mod_pool.nodes.items[mod_index].mod) |m| {
            var level: u8 = 0;

            //handle dependencies
            if(m.properties.dependencies) |deps| {
                for(deps) |dep| {
                    const l = try self.handle_mod(dep);
                    if(l > level) level = l + 1;
                }
            }

            //handle soft dependencies
            if(m.properties.soft_dependencies) |deps| {
                for(deps) |dep| {
                    const l = self.handle_mod(dep) catch {
                        continue;
                    }; //ignore error since dependency isnt required
                    if(l > level) level = l + 1;
                }
            }

            if(self._asmod_mod_pool.nodes.items[mod_index].mod != null) {
                self._asmod_mod_pool.nodes.items[mod_index].mod.?.dependency_level = level;
            }

            self._asmod_mod_queue.push(self._allocator, m) catch return InjectorError.OutOfMemory;

            self._asmod_mod_pool.removeKey(key);

            return level;
        } else {
            return InjectorError.MissingDependency;
        }
    }
};

/// Used for ordering mods in the installation queue.
fn order_mods(context: void, a: Mod, b: Mod) std.math.Order {
    _ = context; //ignored

    if (a.dependency_level < b.dependency_level) {
        return std.math.Order.lt;
    } else if (a.dependency_level == b.dependency_level) {
        return std.math.Order.eq;
    } else {
        return std.math.Order.gt;
    }
}