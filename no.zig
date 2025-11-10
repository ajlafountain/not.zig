const std = @import("std");
const print = std.debug.print;

const not = @import("not.zig");

const Cmd = not.Cmd;
const Packages = not.Packages;

pub fn main() !void {
    try not.rebuild(.{ .remove_old = true });

    const windows = true;

    var deps: Packages = Packages.init();
    try deps.add(.{ .name = "raylib", .url = "raysan5/raylib", .build_cmd = "zig build" });
    try deps.fetch();
    if (windows) {
        try deps.build_with("-Doptimize=ReleaseSmall -Dtarget=x86_64-windows-gnu");
    } else {
        // try deps.build();
        try deps.build_with("-Doptimize=ReleaseSmall");
    }

    var cmd: Cmd = Cmd.init();
    defer cmd.deinit();
    const base_cmd = "zig build-exe src/example.zig --name example";

    try cmd.append_string(base_cmd);
    try deps.append_includes_to(&cmd);
    try cmd.append_string("-lraylib -ldl -lm");
    try cmd.append_string("-O ReleaseSmall -fcompiler-rt");
    try cmd.run();

    cmd.reset();

    if (windows) {
        try cmd.append_string(base_cmd);
        try cmd.append_string("-target x86_64-windows-gnu");
        try cmd.append_string("-O ReleaseSmall -fcompiler-rt");
        try cmd.append_string("--subsystem windows");
        try deps.append_includes_to(&cmd);
        try cmd.append_string("-lraylib -lopengl32 -lgdi32 -lwinmm -lm");
        try cmd.run();
    }

    return;
}
