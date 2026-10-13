const std = @import("std");
const common = @import("../common.zig");

const zip = common.zip;

const InjectionError = common.InjectionError;
const ModFormat = common.ModFormat;
const Mod = common.Mod;

/// Handle for mod injection
pub const ModLib = struct {
    scripts_path: [:0]const u8,
    allocator: std.mem.Allocator,

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
            .allocator = allocator,
        };

        return handle;
    }

    /// Destroys a ModLib handle
    pub fn deinit(self: *ModLib) void {
        _ = self;
    }

    /// Installs a mod using the correct format.
    /// 
    /// **Parameters:**
    /// 
    /// *mod* - mod handle to inject.
    pub fn installMod(self: *ModLib, mod: *Mod) InjectionError!void {
        return switch (mod.format) {
            ModFormat.ASMOD => installAsmod(self, mod),
            ModFormat.ZIP => installZipMod(self, mod),
        };
    }

    /// Installs a mod using the legacy zip format.
    ///
    /// **Params:**
    /// 
    /// *mod* - mod handle to inject.
    fn installZipMod(self: *ModLib, mod: *Mod) InjectionError!void {
        zip.extract(mod.path, self.scripts_path, null, null) catch |err| {
            switch (err) {
                zip.ZipError.FileNotFound => return InjectionError.FileNotFound,
                zip.ZipError.FileOpenFailure => return InjectionError.FileOpenFailure,
                zip.ZipError.FReadError => return InjectionError.FileReadError,
                zip.ZipError.FWriteError => return InjectionError.FileWriteError,
                else => return InjectionError.UnknownError,
            }
        };
    }

    /// Installs a mod using the asmod format.
    ///
    /// **Params:**
    /// 
    /// *mod* - mod handle to inject.
    fn installAsmod(self: *ModLib, mod: *Mod) InjectionError!void {
        _ = self;
        _ = mod;
    }
};