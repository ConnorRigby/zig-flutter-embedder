const std = @import("std");
const glfw = @import("glfw");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("flutter_embedder.h");
});

pub const Embedder = struct {
    allocator: std.mem.Allocator,
    window: glfw.Window,
    resource_window: glfw.Window,
    engine: c.FlutterEngine = undefined,
    pixel_ratio: f64 = 1.0,

    fn make_resource_current_callback(userdata: *allowzero anyopaque) callconv(.C) bool {
        var self = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata));
        glfw.makeContextCurrent(self.resource_window);
        return true;
    }

    fn make_current_callback(userdata: *allowzero anyopaque) callconv(.C) bool {
        var self = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata));
        glfw.makeContextCurrent(self.window);
        return true;
    }

    fn clear_current_callback(userdata: *allowzero anyopaque) callconv(.C) bool {
        var self = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata));
        _ = self;
        glfw.makeContextCurrent(null);
        return true;
    }

    fn present_callback(userdata: *allowzero anyopaque) callconv(.C) bool {
        var self = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata));
        self.window.swapBuffers();
        return true;
    }

    fn fbo_callback(userdata: *allowzero anyopaque) callconv(.C) u32 {
        var self = @ptrCast(*@This(), @alignCast(@alignOf(*@This()), userdata));
        _ = self;
        return 0;
    }

    fn glfw_cursor_position_callback_at_phase(window: glfw.Window, phase: c.FlutterPointerPhase, x: f64, y: f64) void {
        var self = window.getUserPointer(@This()).?;
        var event: c.FlutterPointerEvent = std.mem.zeroes(c.FlutterPointerEvent);
        event.struct_size = @sizeOf(c.FlutterPointerEvent);
        event.phase = phase;
        event.x = x * self.pixel_ratio;
        event.y = y * self.pixel_ratio;
        event.timestamp = @intCast(usize, std.time.microTimestamp());
        _ = c.FlutterEngineSendPointerEvent(self.engine, &event, 1);
    }

    fn glfw_cursor_position_callback(window: glfw.Window, x: f64, y: f64) void {
        glfw_cursor_position_callback_at_phase(window, c.kMove, x, y);
    }

    fn glfw_mouse_button_callback(window: glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) void {
        _ = mods;
        if (button == .left and action == .press) {
            var cursor_pos = window.getCursorPos();
            glfw_cursor_position_callback_at_phase(window, c.kDown, cursor_pos.xpos, cursor_pos.ypos);
            window.setCursorPosCallback(glfw_cursor_position_callback);
        }
        if (button == .left and action == .release) {
            var cursor_pos = window.getCursorPos();
            glfw_cursor_position_callback_at_phase(window, c.kUp, cursor_pos.xpos, cursor_pos.ypos);
            window.setCursorPosCallback(null);
        }
    }

    fn glfw_key_callback(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
        _ = mods;
        _ = scancode;
        if (key == .escape and action == .press) {
            window.setShouldClose(true);
        }
    }

    fn glfw_window_size_callback(window: glfw.Window, width: i32, height: i32) void {
        var self = window.getUserPointer(@This()).?;

        var event: c.FlutterWindowMetricsEvent = std.mem.zeroes(c.FlutterWindowMetricsEvent);
        event.struct_size = @sizeOf(c.FlutterWindowMetricsEvent);
        event.width = @floatToInt(usize, @intToFloat(f64, width) * self.pixel_ratio);
        event.height = @floatToInt(usize, @intToFloat(f64, height) * self.pixel_ratio);
        event.pixel_ratio = self.pixel_ratio;

        _ = c.FlutterEngineSendWindowMetricsEvent(self.engine, &event);
    }

    fn gl_proc_resolver(userdata: ?*anyopaque, name: [*c]const u8) callconv(.C) ?*anyopaque {
        _ = userdata;
        const result = glfw.getProcAddress(name);
        return @ptrCast(*anyopaque, @constCast(result));
    }

    pub fn init(allocator: std.mem.Allocator, window: glfw.Window, assets_path: [:0]const u8, icu_data_path: [:0]const u8) !*@This() {
        var self = try allocator.create(@This());
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.window = window;

        var windowDimensions: glfw.Window.Size = undefined;
        windowDimensions = window.getFramebufferSize();
        self.pixel_ratio = @intToFloat(f64, windowDimensions.width) / @as(f64, 800);

        const resource_window = glfw.Window.create(1, 1, "", null, window, .{
            .decorated = false,
            .visible = false,
            .context_creation_api = .egl_context_api,
        }) orelse {
            std.log.err("failed to create resource window: {?s}", .{glfw.getErrorString()});
            return error.ResourceWindowCreate;
        };
        errdefer resource_window.destroy();
        glfw.Window.defaultHints();
        self.resource_window = resource_window;

        var config: c.FlutterRendererConfig = std.mem.zeroes(c.FlutterRendererConfig);
        config.type = c.kOpenGL;
        config.unnamed_0 = .{ .open_gl = std.mem.zeroes(c.FlutterOpenGLRendererConfig) };
        config.unnamed_0.open_gl.struct_size = @sizeOf(c.FlutterOpenGLRendererConfig);
        config.unnamed_0.open_gl.make_current = &make_current_callback;
        config.unnamed_0.open_gl.make_resource_current = &make_resource_current_callback;
        config.unnamed_0.open_gl.clear_current = &clear_current_callback;
        config.unnamed_0.open_gl.present = &present_callback;
        config.unnamed_0.open_gl.fbo_callback = &fbo_callback;
        config.unnamed_0.open_gl.gl_proc_resolver = &gl_proc_resolver;

        var args: c.FlutterProjectArgs = std.mem.zeroes(c.FlutterProjectArgs);
        args.struct_size = @sizeOf(c.FlutterProjectArgs);
        args.assets_path = assets_path;
        args.icu_data_path = icu_data_path;

        self.engine = std.mem.zeroes(c.FlutterEngine);
        const result: c.FlutterEngineResult = c.FlutterEngineRun(c.FLUTTER_ENGINE_VERSION, &config, &args, self, &self.engine);
        if (result != c.kSuccess or self.engine == null or self.engine == undefined) {
            std.log.err("Could not start flutter engine", .{});
            return error.FlutterEngineRun;
        }
        self.window.setUserPointer(self);
        glfw_window_size_callback(self.window, 800, 600);

        window.setKeyCallback(glfw_key_callback);
        window.setSizeCallback(glfw_window_size_callback);
        window.setMouseButtonCallback(glfw_mouse_button_callback);
        return self;
    }

    pub fn deinit(self: *@This()) void {
        _ = c.FlutterEngineDeinitialize(self.engine);
        self.resource_window.destroy();
        self.allocator.destroy(self);
    }
};
