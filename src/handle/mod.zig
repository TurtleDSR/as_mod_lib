const std = @import("std");
const json = std.json;
const common = @import("../common.zig");

const zip = common.zip;

const ModFormat = common.ModFormat;
const ModHandleError = common.ModHandleError;

const ModList = std.ArrayList(Mod);

/// Handle for a mod instance
pub const Mod = struct {
    /// Path to the mods file on disk.
    path: [:0]const u8,

    /// Format the mod file uses.
    format: ModFormat,

    /// Length of its dependency chain,
    /// defines which installation batch its injected on.
    dependency_level: u8 = 0,

    /// Properties of the mod (name, author, etc.)
    properties: ModProperties = .{},

    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _dependents: ModList = .empty,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _allocator: std.mem.Allocator,
    /// **Note:**
    ///
    /// This field is intended to be used only internally.
    _parsed_properties: ?std.json.Parsed(ModProperties) = null,

    /// Load a mod file into a mod handle.8
    ///
    /// **Parameters:**
    ///
    /// *file* - path to the mod file.
    /// *allocator* - allocator used for reading mod properties if mod is .asmod format.
    ///
    /// **Returns**
    ///
    /// The initialized mod handle.
    ///
    /// **Note**
    ///
    /// Do not forget to call deinit on the returned handle when finished.
    pub fn load(file: [:0]const u8, allocator: std.mem.Allocator) ModHandleError!Mod {
        const format = blk: {
            var buf = [_]u8{'_'} ** 4;
            var form = ModFormat.ASMOD;

            if (std.mem.eql(u8, std.ascii.lowerString(&buf, file[(file.len - 4)..file.len]), ".zip")) {
                form = ModFormat.ZIP;
            }

            break :blk form;
        };

        var m = Mod{
            .path = file,
            .format = format,
            ._allocator = allocator,
        };

        //asmod file should contain properties
        switch (format) {
            ModFormat.ASMOD => { //asmod format
                var z = zip.open(file, zip.defaultCompressionLevel, 'r') catch |err| {
                    return switch (err) {
                        zip.ZipError.FileNotFound => ModHandleError.FileNotFound,
                        zip.ZipError.FileOpenFailure => ModHandleError.FileOpenFailure,
                        zip.ZipError.FReadError => ModHandleError.FileReadError,
                        else => ModHandleError.UnknownError,
                    };
                };
                {
                    defer z.close();

                    z.openEntry("properties.json") catch |err| {
                        if (err != zip.ZipError.EntryNotFound) {
                            return ModHandleError.PropertiesOpenError;
                        }
                    };
                    {
                        defer z.closeEntry();

                        const property_data = z.readEntry(allocator) catch return ModHandleError.PropertiesReadError;
                        defer allocator.free(property_data);

                        const properties = json.parseFromSlice(ModProperties, allocator, property_data, .{
                            .allocate = .alloc_always,
                        }) catch return ModHandleError.PropertiesParseError;

                        m.properties = properties.value;
                        m._parsed_properties = properties;
                    }
                }
            },

            ModFormat.ZIP => { //zip format uses default properties
                m.properties.author = "Unknown";
                m.properties.version = "0.0.0";

                const name_buf = allocator.dupe(u8, std.Io.Dir.path.basename(file[0 .. file.len - 4])) catch return ModHandleError.OutOfMemoryError;
                m.properties.name = name_buf;

                const id_buf = std.mem.concat(allocator, u8, &.{ "com.unknown.", name_buf }) catch return ModHandleError.OutOfMemoryError;
                m.properties.id = id_buf;
            },
        }

        return m;
    }

    /// destroys the mod handle
    pub fn deinit(self: *Mod) void {
        if (self._parsed_properties) |p| {
            p.deinit();
        } else {
            //these are both allocated since they require string mutation.
            self._allocator.free(self.properties.name);
            self._allocator.free(self.properties.id);
        }
    }
};

/// holds the properties found in properties.json
pub const ModProperties = struct {
    author: []const u8 = "",
    name: []const u8 = "",
    id: []const u8 = "",
    version: []const u8 = "",
    source: []const u8 = "",
    soft_dependencies: ?[][]const u8 = null,
    dependencies: ?[][]const u8 = null,
};
