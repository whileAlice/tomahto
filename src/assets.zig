const std = @import("std");

const app_dir = "tomahto";

const AssetId = enum {
    ticking,
    windup,
    ding,
};

pub const Assets = struct {
    ticking_path: []const u8,
    windup_path: []const u8,
    ding_path: []const u8,

    pub fn init(i: std.process.Init) !Assets {
        const xdgDirs = try getXdgDirs(i);
        defer {
            for (xdgDirs) |dir| {
                i.gpa.free(dir);
            }
            i.gpa.free(xdgDirs);
        }

        const ticking_path = try getFilePath(i, "ticking.wav", xdgDirs);
        errdefer {
            i.gpa.free(ticking_path);
        }
        const windup_path = try getFilePath(i, "windup.wav", xdgDirs);
        errdefer {
            i.gpa.free(windup_path);
        }
        const ding_path = try getFilePath(i, "ding.wav", xdgDirs);
        errdefer {
            i.gpa.free(ding_path);
        }

        return .{
            .ticking_path = ticking_path,
            .windup_path = windup_path,
            .ding_path = ding_path,
        };
    }

    pub fn deinit(self: *Assets, i: std.process.Init) void {
        i.gpa.free(self.ticking_path);
        i.gpa.free(self.windup_path);
        i.gpa.free(self.ding_path);
    }

    pub fn getAssetPath(self: Assets, id: AssetId) []const u8 {
        return switch (id) {
            .ticking => self.ticking_path,
            .windup => self.windup_path,
            .ding => self.ding_path,
        };
    }

    fn getFilePath(
        i: std.process.Init,
        filename: []const u8,
        xdgDirs: []const []const u8,
    ) ![]const u8 {
        for (xdgDirs) |share_dir| {
            const file_path = try std.fs.path.join(
                i.gpa,
                &.{
                    share_dir,
                    app_dir,
                    filename,
                },
            );

            if (std.Io.Dir.cwd().access(i.io, file_path, .{})) |_| {
                return file_path;
            } else |_| {
                i.gpa.free(file_path);
            }
        }

        return error.FileNotFound;
    }

    fn getXdgDirs(i: std.process.Init) ![][]const u8 {
        var result: std.ArrayList([]const u8) = .empty;
        errdefer result.deinit(i.gpa);

        if (i.environ_map.get("XDG_DATA_HOME")) |xdg_data_home_dir| {
            if (xdg_data_home_dir.len > 0) {
                try result.append(i.gpa, try i.gpa.dupe(u8, xdg_data_home_dir));
            }
        } else if (i.environ_map.get("HOME")) |home_dir| {
            const data_home_dir = try std.fs.path.join(
                i.gpa,
                &.{ home_dir, ".local", "share" },
            );
            try result.append(i.gpa, data_home_dir);
        } else {
            try result.append(i.gpa, try i.gpa.dupe(u8, "~/.local/share"));
        }

        const xdg_data_dirs = i.environ_map.get("XDG_DATA_DIRS") orelse
            "/usr/local/share:/usr/share";

        var it = std.mem.splitScalar(u8, xdg_data_dirs, ':');
        while (it.next()) |dir| {
            if (dir.len == 0) continue;
            try result.append(i.gpa, try i.gpa.dupe(u8, dir));
        }

        try result.append(i.gpa, try i.gpa.dupe(u8, "../share"));

        return result.toOwnedSlice(i.gpa);
    }
};
