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

        for(self._zip_mod_pool.items) |mod| {
            try self.installZipMod(mod);
        }

        self._asmod_mod_pool.purge();
        self._zip_mod_pool.clearRetainingCapacity();
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

    /// Installs a mod using the asmod format.
    ///
    /// **Params:**
    ///
    /// *mod* - mod handle to inject.
    fn installAsmod(self: *ModLib, mod: Mod) InjectorError!void {
        _ = self;
        _ = mod;
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
