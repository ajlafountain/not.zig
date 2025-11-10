const print = @import("std").debug.print;
const rl = @cImport({
    @cInclude("raylib.h");
});

const rect = struct {
    x: f32 = 200,
    y: f32 = 200,
    w: f32 = 50,
    h: f32 = 50,
    speed: f32 = 500,
    pub fn draw(self: rect) void {
        rl.DrawRectangle(@as(c_int, @intFromFloat(self.x)), @as(c_int, @intFromFloat(self.y)), @as(c_int, @intFromFloat(self.w)), @as(c_int, @intFromFloat(self.h)), rl.RED);
    }
    pub fn update(self: *rect) void {
        if (rl.IsKeyDown(rl.KEY_DOWN)) self.y += self.speed * rl.GetFrameTime();
        if (rl.IsKeyDown(rl.KEY_UP)) self.y -= self.speed * rl.GetFrameTime();
        if (rl.IsKeyDown(rl.KEY_LEFT)) self.x -= self.speed * rl.GetFrameTime();
        if (rl.IsKeyDown(rl.KEY_RIGHT)) self.x += self.speed * rl.GetFrameTime();
    }
};

pub fn main() !void {
    rl.SetTraceLogLevel(rl.LOG_NONE);
    rl.InitWindow(800, 600, "no-zig");
    rl.SetTargetFPS(60);
    var square: rect = .{};

    while (!rl.WindowShouldClose()) {
        square.update();

        rl.BeginDrawing();
        defer rl.EndDrawing();

        square.draw();

        rl.ClearBackground(rl.BLUE);
    }
    return;
}
