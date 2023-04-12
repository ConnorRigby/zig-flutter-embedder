const std = @import("std");
const glfw = @import("glfw");
const zgl = @import("zgl");
const flutter_embedder = @import("flutter_embedder.zig");

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    const window = glfw.Window.create(800, 600, "embedder", null, null, .{
        .context_creation_api = .egl_context_api,
    }) orelse {
        std.log.err("failed to create window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
        unreachable;
    };
    defer window.destroy();

    var embedder = flutter_embedder.Embedder.init(std.heap.c_allocator, window, "myapp/build/flutter_assets", "icudtl.dat") catch {
        std.log.err("failed to start flutter engine", .{});
        std.process.exit(1);
        unreachable;
    };
    defer embedder.deinit();

    while (!window.shouldClose()) {
        glfw.waitEvents();
    }
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?*const anyopaque {
    _ = p;
    return glfw.getProcAddress(proc);
}

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
