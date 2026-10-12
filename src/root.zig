const std = @import("std");
const common = @import("common");

const zip = common.zip;

/// Error type for injection functions.
pub const InjectionError = error {
    FileNotFound,
    FileOpenFailure,
    FileReadError,
    FileWriteError,
    UnknownError,
};

/// Handle for mod injection
pub const ModLib = struct {
    scripts_path: [:0]const u8,

    /// Initializes a ModLib handle.
    ///
    /// **Params:**
    /// 
    /// *scriptsPath* - path to the Scripts directory of the game. 
    /// 
    /// **Returns:**
    /// 
    /// Resulting ModLib handle.
    pub fn init(scriptsPath: [:0]const u8) ModLib {
        const handle: ModLib = .{
            .scripts_path = scriptsPath,
        };

        return handle;
    }

    /// Destroys a ModLib handle
    pub fn destroy() void {}

    /// Installs a mod using the legacy zip format.
    ///
    /// **Params:**
    /// 
    /// *file* - path to the zip file to inject.
    pub fn installZipMod(self: *ModLib, file: [:0]const u8) InjectionError!void {
        zip.extract(file, self.scripts_path, null, null) catch |err| {
            switch (err) {
                zip.ZipError.FileNotFound => return InjectionError.FileNotFound,
                zip.ZipError.FileOpenFailure => return InjectionError.FileOpenFailure,
                zip.ZipError.FReadError => return InjectionError.FileReadError,
                zip.ZipError.FWriteError => return InjectionError.FileWriteError,
                else => return InjectionError.UnknownError,
            }
        };
    }
};