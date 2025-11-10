const std = @import("std");
const print = std.debug.print;
const fs = std.fs;
pub const BUFFER_SIZE = 1024;
pub const Cmd = struct {
    arena: std.heap.ArenaAllocator,
    list: std.ArrayList([]const u8) = .empty,

    pub fn init() Cmd {
        return .{
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *Cmd) void {
        self.list.deinit(self.arena.allocator());
        self.arena.deinit();
    }

    pub fn reset(self: *Cmd) void {
        self.list.clearRetainingCapacity();
    }

    pub fn append(self: *Cmd, word: []const u8) !void {
        const duped_word = try self.arena.allocator().dupe(u8, word);
        try self.list.append(self.arena.allocator(), duped_word);
    }
    pub fn appendf(self: *Cmd, comptime word: []const u8, args: anytype) !void {
        var buffer: [BUFFER_SIZE]u8 = undefined;
        const fmt_word = try std.fmt.bufPrint(&buffer, word, args);
        try self.append(fmt_word);
    }

    pub fn append_string(self: *Cmd, string: []const u8) !void {
        var iterator = std.mem.splitScalar(u8, string, ' ');
        while (iterator.next()) |word| {
            try self.append(word);
        }
    }
    pub fn append_stringf(self: *Cmd, comptime string: []const u8, args: anytype) !void {
        var buffer: [BUFFER_SIZE]u8 = undefined;
        const fmt_string = try std.fmt.bufPrint(&buffer, string, args);
        var iterator = std.mem.splitScalar(u8, fmt_string, ' ');
        while (iterator.next()) |word| {
            try self.append(word);
        }
    }

    pub fn run(self: *Cmd) !void {
        var child = std.process.Child.init(self.list.items, self.arena.allocator());
        try child.spawn();
        const exit_code = try child.wait();
        switch (exit_code) {
            .Exited => |code| {
                print("Command \"{s}\" finished with code: {d}\n", .{ self.list.items[0], code });
            },
            else => {},
        }
    }
};

pub const Package = struct {
    //Assumes some sort of git repository
    name: []const u8 = "",
    url: []const u8 = "",
    version: []const u8 = "",
    build_cmd: []const u8 = "zig build",
};

pub const Packages = struct {
    arena: std.heap.ArenaAllocator,
    list: std.ArrayList(Package) = .empty,
    pub fn init() Packages {
        return .{
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
        };
    }
    pub fn reset(self: *Packages) void {
        self.list.clearRetainingCapacity();
    }
    pub fn deinit(self: *Packages) void {
        self.list.deinit(self.arena.allocator());
        self.arena.deinit();
    }
    pub fn add(self: *Packages, pkg: Package) !void {
        try self.list.append(self.arena.allocator(), pkg);
    }
    pub fn fetch(self: *Packages) !void {
        // Check/create include directory
        const cwd = fs.cwd();
        const starting_dir = try cwd.openDir("./", .{});
        cwd.makeDir("./include") catch |err| {
            switch (err) {
                error.PathAlreadyExists => {},
                else => {
                    return err;
                },
            }
        };
        var include_dir = try cwd.openDir("./include", .{});
        var git_cmd = Cmd.init();
        defer git_cmd.deinit();
        for (self.list.items) |package| {
            defer git_cmd.reset();
            try include_dir.setAsCwd();
            _ = include_dir.openDir(package.name, .{}) catch |err| {
                switch (err) {
                    error.FileNotFound => {
                        try git_cmd.append_stringf("git clone https://github.com/{s}.git", .{package.url});
                        try git_cmd.run();
                    },
                    else => {
                        return err;
                    },
                }
            };
            try starting_dir.setAsCwd();
        }
    }
    pub fn build(self: *Packages) !void {
        const cwd = fs.cwd();
        const starting_dir = try cwd.openDir("./", .{});
        const include_dir = try cwd.openDir("./include", .{});

        var build_cmd = Cmd.init();
        defer build_cmd.deinit();

        for (self.list.items) |package| {
            defer build_cmd.reset();

            const package_dir = try include_dir.openDir(package.name, .{});

            try package_dir.setAsCwd();
            try build_cmd.append_string(package.build_cmd);
            try build_cmd.run();
            try starting_dir.setAsCwd();
        }
    }
    pub fn build_with(self: *Packages, string: []const u8) !void {
        const cwd = fs.cwd();
        const starting_dir = try cwd.openDir("./", .{});
        const include_dir = try cwd.openDir("./include", .{});

        var build_cmd = Cmd.init();
        defer build_cmd.deinit();

        for (self.list.items) |package| {
            defer build_cmd.reset();

            const package_dir = try include_dir.openDir(package.name, .{});

            try package_dir.setAsCwd();
            try build_cmd.append_string(package.build_cmd);
            try build_cmd.append_string(string);
            try build_cmd.run();
            try starting_dir.setAsCwd();
        }
    }
    // TODO flags
    pub fn append_includes_to(self: *Packages, cmd: *Cmd) !void {
        for (self.list.items) |package| {
            try cmd.appendf("-L./include/{s}/zig-out/lib", .{package.name});
            try cmd.appendf("-I./include/{s}/zig-out/include", .{package.name});
        }
    }
};

fn move_binary(allocator: std.mem.Allocator) !void {
    const mv_argv = [_][]const u8{ "mv", "no", "no.old" };
    var mv_child = std.process.Child.init(&mv_argv, allocator);
    try mv_child.spawn();
    const mv_exit_code = try mv_child.wait();

    switch (mv_exit_code) {
        .Exited => |code| {
            if (code != 0) {
                print("Move failed with code: {d}\n", .{code});
            } else {
                print("Moved running executable to no.old!\n", .{});
            }
        },
        else => {
            print("EXTREME MOVE FAILURE!\n", .{});
        },
    }
}
fn move_binary_back(allocator: std.mem.Allocator) !void {
    const mv_argv = [_][]const u8{ "mv", "no.old", "no" };
    var mv_child = std.process.Child.init(&mv_argv, allocator);
    try mv_child.spawn();
    const mv_exit_code = try mv_child.wait();

    switch (mv_exit_code) {
        .Exited => |code| {
            if (code != 0) {
                print("Move failed with code: {d}\n", .{code});
            } else {
                print("Moved running executable back!\n", .{});
            }
        },
        else => {
            print("EXTREME MOVE FAILURE!\n", .{});
        },
    }
}

fn build_and_replace() !void {
    const cwd = fs.cwd();
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("LEAK");
    }

    print("Rebuilding!\n", .{});
    try move_binary(allocator);

    const argv = [_][]const u8{ "zig", "build-exe", "no.zig" };
    var child = std.process.Child.init(&argv, allocator);

    try child.spawn();
    const exit_code = try child.wait();

    switch (exit_code) {
        .Exited => |code| {
            if (code != 0) {
                print("Rebuild failed with code: {d}\n", .{code});
                cwd.deleteFile("no") catch {};
                try move_binary_back(allocator);
                std.process.exit(code);
            } else {
                print("Rebuild done!\n", .{});
            }
        },
        else => {
            print("Failure!\n", .{});
        },
    }
    const args_array = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args_array);

    const execv_err = std.process.execv(allocator, args_array);
    print("Error replacing process with new build: {}\n", .{execv_err});
}

pub fn rebuild(options: struct { remove_old: bool = false, every_time: bool = false }) !void {
    //Remove the old binary
    const cwd = fs.cwd();
    if (options.remove_old) {
        if (cwd.deleteFile("no.old")) {
            print("Removing old binary\n", .{});
        } else |_| {}
    }

    //Get the current binary stats
    const self_exe = try fs.openSelfExe(.{});
    const self_stat = try self_exe.stat();
    self_exe.close();

    //Get the source file stats
    const no = try cwd.openFile("no.zig", .{});
    const no_stat = try no.stat();
    no.close();

    //Check to see if we need to rebuild
    if (self_stat.mtime < no_stat.mtime) {
        try build_and_replace();
    } else if (options.every_time) {
        const lock_file_name: []const u8 = "not_time_lock";
        if (cwd.access(lock_file_name, .{})) {
            try cwd.deleteFile(lock_file_name);
        } else |_| {
            var lock_file_handle = try cwd.createFile(lock_file_name, .{});
            lock_file_handle.close();
            try build_and_replace();
        }
    }
}
pub fn noz() void {
    print("NOZ!\n", .{});
    return;
}

const seperator = "---------------------------\n";
test "packages" {
    var deps: Packages = Packages.init();
    defer deps.deinit();

    try deps.add(.{ .name = "DepOne", .url = "what", .build_cmd = "echo build 0" });
    try deps.add(.{ .name = "DepTwo", .url = "what", .build_cmd = "echo build 1" });
    try deps.add(.{ .name = "DepThree", .url = "what", .build_cmd = "echo build 2" });

    print("Checking item validity: \n", .{});
    var test_cmd = Cmd.init();
    for (deps.list.items) |package| {
        print(seperator, .{});
        print("\tname: {s}\n", .{package.name});
        print("\turl: {s}\n", .{package.url});
        print("\tbuild_cmd: {s}\n", .{package.build_cmd});
        try test_cmd.append_string(package.build_cmd);
        try test_cmd.run();
        test_cmd.reset();
    }
    test_cmd.deinit();
    print(seperator, .{});
    deps.reset();

    try deps.add(.{ .name = "raylib", .url = "raysan5/raylib", .build_cmd = "zig build" });
    try deps.fetch();

    var test_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer test_allocator.deinit();
    const cwd = std.fs.cwd();
    const cwd_path = try cwd.realpathAlloc(test_allocator.allocator(), "./");
    print("CWD path: {s}\n", .{cwd_path});

    try deps.build();
    try deps.build_with("-Dtarget=x86_64-windows-gnu");

    // TODO flags
    // var flags: []u8 = undefined;
    // try deps.write_flags(flags);
    // print("Flags: {s}\n", .{flags});
}
test "echo" {
    var echo: Cmd = Cmd.init();
    try echo.append("echo");
    try echo.append("Hello");
    try echo.append("world!");
    echo.run() catch |err| {
        print("Failed to run echo: {}\n", .{err});
    };
    echo.reset();

    try echo.append("echo");
    try echo.append("Number2");
    try echo.run();
    echo.reset();

    try echo.append_stringf("echo {s}", .{"fmt test"});
    print("Checking append_stringf result:\n", .{});
    for (echo.list.items) |word| {
        print("\tword: {s}\n", .{word});
    }
    try echo.run();
    echo.reset();

    try echo.append("echo");
    try echo.append_string("appendf test");
    try echo.appendf("{}", .{true});
    try echo.run();
    echo.deinit();
}
