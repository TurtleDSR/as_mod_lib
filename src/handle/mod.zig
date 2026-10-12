const std = @import("std");
const common = @import("../common.zig");

const zip = common.zip;

const ModFormat = common.ModFormat;

/// Handle for a mod instance
pub const Mod = struct {
    path: [:0]const u8,
    format: ModFormat,
    
    /// Load a mod file into a mod handle.
    /// 
    /// **Parameters:**
    /// 
    /// *file* - path to the mod file.
    /// 
    /// **Returns**
    /// 
    /// The initialized mod handle.
    pub fn load(file: [:0]const u8) !Mod {
        return .{
            .path = file,
            .format = ModFormat.ZIP,
        };
    }
};