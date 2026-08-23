const std = @import("std");
const sdl = @import("sdl3");
const shader_module = @import("shader");

/// What we send to the GPU
pub const Vertex = extern struct {
    xy: [2]f32,
    uv: [2]f32,
};

/// Vertices of our example quad
const ExampleQuadVertices = [4]Vertex{
    .{ .xy = .{ -0.5, -0.5 }, .uv = .{ 0.0, 0.0 } },
    .{ .xy = .{ 0.5, -0.5 }, .uv = .{ 1.0, 0.0 } },
    .{ .xy = .{ 0.5, 0.5 }, .uv = .{ 1.0, 1.0 } },
    .{ .xy = .{ -0.5, 0.5 }, .uv = .{ 0.0, 1.0 } },
};

/// Indices of our example quad
const ExampleQuadIndices = [6]u16{ 0, 1, 2, 0, 2, 3 };

/// Our error set for SDL3
pub const SDL3Error = error{
    LibraryInitialization,
    UnexpectedNullPointer,
    WindowInitialization,
    GPUInitialization,
    GPUInteraction,
};

/// Ergonomic wrapper to specify the SDL3 shader backend
pub const SDL3ShaderFormat = enum(u32) {
    spirv = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
    dxbc = sdl.SDL_GPU_SHADERFORMAT_DXBC,
    dxil = sdl.SDL_GPU_SHADERFORMAT_DXIL,
    msl = sdl.SDL_GPU_SHADERFORMAT_MSL,
    metal = sdl.SDL_GPU_SHADERFORMAT_METALLIB,
};

/// Ergonomic wrapper to capture SDL events
const SDL3EventEnum = enum(u32) {
    SDL_EVENT_QUIT = sdl.SDL_EVENT_QUIT,
    SDL_EVENT_TERMINATING = sdl.SDL_EVENT_TERMINATING,
    SDL_EVENT_LOW_MEMORY = sdl.SDL_EVENT_LOW_MEMORY,
    SDL_EVENT_WILL_ENTER_BACKGROUND = sdl.SDL_EVENT_WILL_ENTER_BACKGROUND,
    SDL_EVENT_DID_ENTER_BACKGROUND = sdl.SDL_EVENT_DID_ENTER_BACKGROUND,
    SDL_EVENT_WILL_ENTER_FOREGROUND = sdl.SDL_EVENT_WILL_ENTER_FOREGROUND,
    SDL_EVENT_DID_ENTER_FOREGROUND = sdl.SDL_EVENT_DID_ENTER_FOREGROUND,
    SDL_EVENT_LOCALE_CHANGED = sdl.SDL_EVENT_LOCALE_CHANGED,
    SDL_EVENT_SYSTEM_THEME_CHANGED = sdl.SDL_EVENT_SYSTEM_THEME_CHANGED,
    SDL_EVENT_DISPLAY_ORIENTATION = sdl.SDL_EVENT_DISPLAY_ORIENTATION,
    SDL_EVENT_DISPLAY_ADDED = sdl.SDL_EVENT_DISPLAY_ADDED,
    SDL_EVENT_DISPLAY_REMOVED = sdl.SDL_EVENT_DISPLAY_REMOVED,
    SDL_EVENT_DISPLAY_MOVED = sdl.SDL_EVENT_DISPLAY_MOVED,
    SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED = sdl.SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED,
    SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED = sdl.SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED,
    SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED = sdl.SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED,
    SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED = sdl.SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED,
    SDL_EVENT_WINDOW_SHOWN = sdl.SDL_EVENT_WINDOW_SHOWN,
    SDL_EVENT_WINDOW_HIDDEN = sdl.SDL_EVENT_WINDOW_HIDDEN,
    SDL_EVENT_WINDOW_EXPOSED = sdl.SDL_EVENT_WINDOW_EXPOSED,
    SDL_EVENT_WINDOW_MOVED = sdl.SDL_EVENT_WINDOW_MOVED,
    SDL_EVENT_WINDOW_RESIZED = sdl.SDL_EVENT_WINDOW_RESIZED,
    SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED = sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
    SDL_EVENT_WINDOW_METAL_VIEW_RESIZED = sdl.SDL_EVENT_WINDOW_METAL_VIEW_RESIZED,
    SDL_EVENT_WINDOW_MINIMIZED = sdl.SDL_EVENT_WINDOW_MINIMIZED,
    SDL_EVENT_WINDOW_MAXIMIZED = sdl.SDL_EVENT_WINDOW_MAXIMIZED,
    SDL_EVENT_WINDOW_RESTORED = sdl.SDL_EVENT_WINDOW_RESTORED,
    SDL_EVENT_WINDOW_MOUSE_ENTER = sdl.SDL_EVENT_WINDOW_MOUSE_ENTER,
    SDL_EVENT_WINDOW_MOUSE_LEAVE = sdl.SDL_EVENT_WINDOW_MOUSE_LEAVE,
    SDL_EVENT_WINDOW_FOCUS_GAINED = sdl.SDL_EVENT_WINDOW_FOCUS_GAINED,
    SDL_EVENT_WINDOW_FOCUS_LOST = sdl.SDL_EVENT_WINDOW_FOCUS_LOST,
    SDL_EVENT_WINDOW_CLOSE_REQUESTED = sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
    SDL_EVENT_WINDOW_HIT_TEST = sdl.SDL_EVENT_WINDOW_HIT_TEST,
    SDL_EVENT_WINDOW_ICCPROF_CHANGED = sdl.SDL_EVENT_WINDOW_ICCPROF_CHANGED,
    SDL_EVENT_WINDOW_DISPLAY_CHANGED = sdl.SDL_EVENT_WINDOW_DISPLAY_CHANGED,
    SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED = sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
    SDL_EVENT_WINDOW_SAFE_AREA_CHANGED = sdl.SDL_EVENT_WINDOW_SAFE_AREA_CHANGED,
    SDL_EVENT_WINDOW_OCCLUDED = sdl.SDL_EVENT_WINDOW_OCCLUDED,
    SDL_EVENT_WINDOW_ENTER_FULLSCREEN = sdl.SDL_EVENT_WINDOW_ENTER_FULLSCREEN,
    SDL_EVENT_WINDOW_LEAVE_FULLSCREEN = sdl.SDL_EVENT_WINDOW_LEAVE_FULLSCREEN,
    SDL_EVENT_WINDOW_DESTROYED = sdl.SDL_EVENT_WINDOW_DESTROYED,
    SDL_EVENT_WINDOW_HDR_STATE_CHANGED = sdl.SDL_EVENT_WINDOW_HDR_STATE_CHANGED,
    SDL_EVENT_KEY_DOWN = sdl.SDL_EVENT_KEY_DOWN,
    SDL_EVENT_KEY_UP = sdl.SDL_EVENT_KEY_UP,
    SDL_EVENT_TEXT_EDITING = sdl.SDL_EVENT_TEXT_EDITING,
    SDL_EVENT_TEXT_INPUT = sdl.SDL_EVENT_TEXT_INPUT,
    SDL_EVENT_KEYMAP_CHANGED = sdl.SDL_EVENT_KEYMAP_CHANGED,
    SDL_EVENT_KEYBOARD_ADDED = sdl.SDL_EVENT_KEYBOARD_ADDED,
    SDL_EVENT_KEYBOARD_REMOVED = sdl.SDL_EVENT_KEYBOARD_REMOVED,
    SDL_EVENT_TEXT_EDITING_CANDIDATES = sdl.SDL_EVENT_TEXT_EDITING_CANDIDATES,
    SDL_EVENT_SCREEN_KEYBOARD_SHOWN = sdl.SDL_EVENT_SCREEN_KEYBOARD_SHOWN,
    SDL_EVENT_SCREEN_KEYBOARD_HIDDEN = sdl.SDL_EVENT_SCREEN_KEYBOARD_HIDDEN,
    SDL_EVENT_MOUSE_MOTION = sdl.SDL_EVENT_MOUSE_MOTION,
    SDL_EVENT_MOUSE_BUTTON_DOWN = sdl.SDL_EVENT_MOUSE_BUTTON_DOWN,
    SDL_EVENT_MOUSE_BUTTON_UP = sdl.SDL_EVENT_MOUSE_BUTTON_UP,
    SDL_EVENT_MOUSE_WHEEL = sdl.SDL_EVENT_MOUSE_WHEEL,
    SDL_EVENT_MOUSE_ADDED = sdl.SDL_EVENT_MOUSE_ADDED,
    SDL_EVENT_MOUSE_REMOVED = sdl.SDL_EVENT_MOUSE_REMOVED,
    SDL_EVENT_JOYSTICK_AXIS_MOTION = sdl.SDL_EVENT_JOYSTICK_AXIS_MOTION,
    SDL_EVENT_JOYSTICK_BALL_MOTION = sdl.SDL_EVENT_JOYSTICK_BALL_MOTION,
    SDL_EVENT_JOYSTICK_HAT_MOTION = sdl.SDL_EVENT_JOYSTICK_HAT_MOTION,
    SDL_EVENT_JOYSTICK_BUTTON_DOWN = sdl.SDL_EVENT_JOYSTICK_BUTTON_DOWN,
    SDL_EVENT_JOYSTICK_BUTTON_UP = sdl.SDL_EVENT_JOYSTICK_BUTTON_UP,
    SDL_EVENT_JOYSTICK_ADDED = sdl.SDL_EVENT_JOYSTICK_ADDED,
    SDL_EVENT_JOYSTICK_REMOVED = sdl.SDL_EVENT_JOYSTICK_REMOVED,
    SDL_EVENT_JOYSTICK_BATTERY_UPDATED = sdl.SDL_EVENT_JOYSTICK_BATTERY_UPDATED,
    SDL_EVENT_JOYSTICK_UPDATE_COMPLETE = sdl.SDL_EVENT_JOYSTICK_UPDATE_COMPLETE,
    SDL_EVENT_GAMEPAD_AXIS_MOTION = sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION,
    SDL_EVENT_GAMEPAD_BUTTON_DOWN = sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN,
    SDL_EVENT_GAMEPAD_BUTTON_UP = sdl.SDL_EVENT_GAMEPAD_BUTTON_UP,
    SDL_EVENT_GAMEPAD_ADDED = sdl.SDL_EVENT_GAMEPAD_ADDED,
    SDL_EVENT_GAMEPAD_REMOVED = sdl.SDL_EVENT_GAMEPAD_REMOVED,
    SDL_EVENT_GAMEPAD_REMAPPED = sdl.SDL_EVENT_GAMEPAD_REMAPPED,
    SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN = sdl.SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN,
    SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION = sdl.SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION,
    SDL_EVENT_GAMEPAD_TOUCHPAD_UP = sdl.SDL_EVENT_GAMEPAD_TOUCHPAD_UP,
    SDL_EVENT_GAMEPAD_SENSOR_UPDATE = sdl.SDL_EVENT_GAMEPAD_SENSOR_UPDATE,
    SDL_EVENT_GAMEPAD_UPDATE_COMPLETE = sdl.SDL_EVENT_GAMEPAD_UPDATE_COMPLETE,
    SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED = sdl.SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED,
    SDL_EVENT_FINGER_DOWN = sdl.SDL_EVENT_FINGER_DOWN,
    SDL_EVENT_FINGER_UP = sdl.SDL_EVENT_FINGER_UP,
    SDL_EVENT_FINGER_MOTION = sdl.SDL_EVENT_FINGER_MOTION,
    SDL_EVENT_FINGER_CANCELED = sdl.SDL_EVENT_FINGER_CANCELED,
    SDL_EVENT_PINCH_BEGIN = sdl.SDL_EVENT_PINCH_BEGIN,
    SDL_EVENT_PINCH_UPDATE = sdl.SDL_EVENT_PINCH_UPDATE,
    SDL_EVENT_PINCH_END = sdl.SDL_EVENT_PINCH_END,
    SDL_EVENT_CLIPBOARD_UPDATE = sdl.SDL_EVENT_CLIPBOARD_UPDATE,
    SDL_EVENT_DROP_FILE = sdl.SDL_EVENT_DROP_FILE,
    SDL_EVENT_DROP_TEXT = sdl.SDL_EVENT_DROP_TEXT,
    SDL_EVENT_DROP_BEGIN = sdl.SDL_EVENT_DROP_BEGIN,
    SDL_EVENT_DROP_COMPLETE = sdl.SDL_EVENT_DROP_COMPLETE,
    SDL_EVENT_DROP_POSITION = sdl.SDL_EVENT_DROP_POSITION,
    SDL_EVENT_AUDIO_DEVICE_ADDED = sdl.SDL_EVENT_AUDIO_DEVICE_ADDED,
    SDL_EVENT_AUDIO_DEVICE_REMOVED = sdl.SDL_EVENT_AUDIO_DEVICE_REMOVED,
    SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED = sdl.SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED,
    SDL_EVENT_SENSOR_UPDATE = sdl.SDL_EVENT_SENSOR_UPDATE,
    SDL_EVENT_PEN_PROXIMITY_IN = sdl.SDL_EVENT_PEN_PROXIMITY_IN,
    SDL_EVENT_PEN_PROXIMITY_OUT = sdl.SDL_EVENT_PEN_PROXIMITY_OUT,
    SDL_EVENT_PEN_DOWN = sdl.SDL_EVENT_PEN_DOWN,
    SDL_EVENT_PEN_UP = sdl.SDL_EVENT_PEN_UP,
    SDL_EVENT_PEN_BUTTON_DOWN = sdl.SDL_EVENT_PEN_BUTTON_DOWN,
    SDL_EVENT_PEN_BUTTON_UP = sdl.SDL_EVENT_PEN_BUTTON_UP,
    SDL_EVENT_PEN_MOTION = sdl.SDL_EVENT_PEN_MOTION,
    SDL_EVENT_PEN_AXIS = sdl.SDL_EVENT_PEN_AXIS,
    SDL_EVENT_CAMERA_DEVICE_ADDED = sdl.SDL_EVENT_CAMERA_DEVICE_ADDED,
    SDL_EVENT_CAMERA_DEVICE_REMOVED = sdl.SDL_EVENT_CAMERA_DEVICE_REMOVED,
    SDL_EVENT_CAMERA_DEVICE_APPROVED = sdl.SDL_EVENT_CAMERA_DEVICE_APPROVED,
    SDL_EVENT_CAMERA_DEVICE_DENIED = sdl.SDL_EVENT_CAMERA_DEVICE_DENIED,
    SDL_EVENT_RENDER_TARGETS_RESET = sdl.SDL_EVENT_RENDER_TARGETS_RESET,
    SDL_EVENT_RENDER_DEVICE_RESET = sdl.SDL_EVENT_RENDER_DEVICE_RESET,
    SDL_EVENT_RENDER_DEVICE_LOST = sdl.SDL_EVENT_RENDER_DEVICE_LOST,
    SDL_EVENT_PRIVATE0 = sdl.SDL_EVENT_PRIVATE0,
    SDL_EVENT_PRIVATE1 = sdl.SDL_EVENT_PRIVATE1,
    SDL_EVENT_PRIVATE2 = sdl.SDL_EVENT_PRIVATE2,
    SDL_EVENT_PRIVATE3 = sdl.SDL_EVENT_PRIVATE3,
    SDL_EVENT_POLL_SENTINEL = sdl.SDL_EVENT_POLL_SENTINEL,
    _,
};

/// Complete set of settings specifying the behaviour of the app
pub const ProgramSettings = struct {
    shader_format: SDL3ShaderFormat,
    enable_gpu_debug: bool,
    window_w: u32,
    window_h: u32,
};

/// Helper struct typing dimensions to an SDL swapchain texture
const SwapchainTexture = struct {
    tex: *sdl.SDL_GPUTexture,
    w: u32,
    h: u32,
};

/// Name of our window
const WindowName: [*:0]const u8 = "vibe-patcher";

/// Our default clear color
const ClearColor = sdl.SDL_FColor{ .r = 0.09, .g = 0.09, .b = 0.11, .a = 1.0 };

/// Initialize the SDL3 library with the specified subsystems
fn SDL3Initialize() SDL3Error!void {
    std.log.info("Initializing SDL3 backend...", .{});
    errdefer std.log.err("Initializing SDL3 backend failed: '{s}'", .{sdl.SDL_GetError()});

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO)) {
        return SDL3Error.LibraryInitialization;
    }

    std.log.info("Initializing SDL3 backend OK", .{});
}

/// Clean up the specified SDL3 subsystems
fn SDL3Quit() void {
    std.log.info("Destroying SDL3 subsystems", .{});
    sdl.SDL_Quit();
}

/// Create an SDL3 GPU context
fn SDL3CreateGPUDevice(shader_format: SDL3ShaderFormat, debug: bool) SDL3Error!*sdl.SDL_GPUDevice {
    std.log.info("Creating SDL3 GPU device...", .{});
    errdefer std.log.err("Creating SDL3 GPU device failed: '{s}'", .{sdl.SDL_GetError()});

    const device = sdl.SDL_CreateGPUDevice(@intFromEnum(shader_format), debug, null) orelse {
        return SDL3Error.UnexpectedNullPointer;
    };

    std.log.info("Creating SDL3 GPU device OK", .{});
    return device;
}

/// Destroy the SDL3 GPU context
fn SDL3DestroyGPUDevice(device: *sdl.SDL_GPUDevice) void {
    std.log.info("Destroying SDL3 GPU device", .{});
    sdl.SDL_DestroyGPUDevice(device);
}

/// Create an SDL3 window
fn SDL3CreateWindow(title: [*:0]const u8, w: u32, h: u32) SDL3Error!*sdl.SDL_Window {
    std.log.info("Creating SDL3 Window...", .{});
    errdefer std.log.err("Creating SDL3 GPU device failed: '{s}'", .{sdl.SDL_GetError()});

    const flags = sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY;
    const window = sdl.SDL_CreateWindow(title, @intCast(w), @intCast(h), flags) orelse {
        return SDL3Error.UnexpectedNullPointer;
    };

    std.log.info("Creating SDL3 Window OK", .{});
    return window;
}

/// Destroy the SDL3 window
fn SDL3DestroyWindow(window: *sdl.SDL_Window) void {
    std.log.info("Destroying SDL3 GPU Window", .{});
    sdl.SDL_DestroyWindow(window);
}

/// Claim the SDL3 window to the gpu
fn SDL3GPUClaimWindow(device: *sdl.SDL_GPUDevice, window: *sdl.SDL_Window) SDL3Error!void {
    std.log.info("Claiming SDL3 window for our GPU...", .{});
    errdefer std.log.err("Claiming SDL3 window for our GPU failed: '{s}'", .{sdl.SDL_GetError()});

    if (sdl.SDL_ClaimWindowForGPUDevice(device, window) != true) {
        return SDL3Error.GPUInitialization;
    }

    std.log.info("Claiming SDL3 window for our GPU OK", .{});
}

/// Claim the SDL3 window from the GPU
fn SDL3GPUDestroyWindow(device: *sdl.SDL_GPUDevice, window: *sdl.SDL_Window) void {
    std.log.info("Destroying SDL3 window", .{});

    sdl.SDL_ReleaseWindowFromGPUDevice(device, window);
}

/// Acquire a command buffer from an SDL3 GPU
fn SDL3AcquireGPUCommandBuffer(device: *sdl.SDL_GPUDevice) SDL3Error!*sdl.SDL_GPUCommandBuffer {
    std.log.debug("Acquiring command buffer from SDL3 GPU...", .{});
    errdefer std.log.err("Acquiring command buffer from SDL3 GPU failed: '{s}'", .{sdl.SDL_GetError()});

    const command_buffer = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.debug("Acquiring command buffer from SDL3 GPU OK", .{});
    return command_buffer;
}

/// Submit a command buffer to the SDL3 GPU
fn SDL3SubmitGPUCommandBuffer(command_buffer: *sdl.SDL_GPUCommandBuffer) SDL3Error!void {
    const str = "Submitting command buffer to SDL3 GPU";
    std.log.debug("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    if (!sdl.SDL_SubmitGPUCommandBuffer(command_buffer)) {
        return SDL3Error.GPUInteraction;
    }

    std.log.debug("{s} OK", .{str});
}

/// Begin a SDL3 GPU render pass
fn SDL3BeginGPURenderPass(
    command_buffer: *sdl.SDL_GPUCommandBuffer,
    color_target_infos: []const sdl.SDL_GPUColorTargetInfo,
    depth_stencil_target_info: ?*sdl.SDL_GPUDepthStencilTargetInfo,
) SDL3Error!*sdl.SDL_GPURenderPass {
    const str = "Beginning SDL3 GPU render pass";
    std.log.debug("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const render_pass = sdl.SDL_BeginGPURenderPass(
        command_buffer,
        color_target_infos.ptr,
        @intCast(color_target_infos.len),
        depth_stencil_target_info,
    ) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.debug("{s} OK", .{str});
    return render_pass;
}

/// End a SDL3 GPU render pass
fn SDL3EndGPURenderPass(
    render_pass: *sdl.SDL_GPURenderPass,
) void {
    const str = "Ending SDL3 GPU render pass";
    std.log.debug("{s}", .{str});

    sdl.SDL_EndGPURenderPass(render_pass);
}

/// Block until we can acquire a swapchain texture. Blocking dictated by vsync.
fn SDL3AcquireGPUSwapchainTextureBlocking(
    command_buffer: *sdl.SDL_GPUCommandBuffer,
    window: *sdl.SDL_Window,
) SDL3Error!?SwapchainTexture {
    const str = "Acquiring SDL3 GPU swapchain texture";
    std.log.debug("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    var w: u32 = 0;
    var h: u32 = 0;
    var texture: ?*sdl.SDL_GPUTexture = null;
    if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(
        command_buffer,
        window,
        &texture,
        &w,
        &h,
    )) {
        return SDL3Error.GPUInteraction;
    }

    if (texture) |tex| {
        std.log.debug("{s} OK", .{str});
        return SwapchainTexture{
            .tex = tex,
            .w = w,
            .h = h,
        };
    } else {
        std.log.info("{s} resulted in null texture, app possibly minimized", .{str});
        return null;
    }
}

/// Helper function to print an SDL3 Event
fn SDL3EventName(event: u32) []const u8 {
    return switch (@as(SDL3EventEnum, @enumFromInt(event))) {
        _ => "SDL_EVENT_UNKNOWN",
        inline else => |tag| @tagName(tag),
    };
}

/// Polls for an SDL3 event
fn SDL3PollEvent() ?sdl.SDL_Event {
    var event = std.mem.zeroes(sdl.SDL_Event);
    if (sdl.SDL_PollEvent(&event)) {
        std.log.info("Got SDL3 event with type '{s}'", .{SDL3EventName(event.type)});
        return event;
    }

    return null;
}

/// Load a SDL3 GPU shader from bytecode
fn SDL3GPUCreateShader(device: *sdl.SDL_GPUDevice, shader: shader_module.Shader) SDL3Error!*sdl.SDL_GPUShader {
    const str = "Creating SDL3 GPU shader...";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const sdl_shader = sdl.SDL_CreateGPUShader(
        device,
        &sdl.SDL_GPUShaderCreateInfo{
            .code_size = shader.code.len,
            .code = shader.code.ptr,
            .entrypoint = "main",
            .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = switch (shader.kind) {
                .FRAG => sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
                .VERT => sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            },

            // Remaining options
            .num_samplers = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0,
            .num_storage_textures = 0,
        },
    ) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.info("{s} OK", .{str});
    return sdl_shader;
}

/// Destroy a SDL3 GPU shader
fn SDL3GPUDestroyShader(device: *sdl.SDL_GPUDevice, shader: *sdl.SDL_GPUShader) void {
    std.log.info("Destroying SDL3 shader", .{});

    sdl.SDL_ReleaseGPUShader(device, shader);
}

/// Create an SDL3 graphics pipeline
fn SDL3GPUCreateGraphicsPipeline(
    device: *sdl.SDL_GPUDevice,
    window: *sdl.SDL_Window,
    vert: *sdl.SDL_GPUShader,
    frag: *sdl.SDL_GPUShader,
) SDL3Error!*sdl.SDL_GPUGraphicsPipeline {
    const str = "Creating SDL3 GPU graphics pipeline...";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const color_targets = [_]sdl.SDL_GPUColorTargetDescription{
        sdl.SDL_GPUColorTargetDescription{
            .format = sdl.SDL_GetGPUSwapchainTextureFormat(device, window),

            // Remaining
            .blend_state = std.mem.zeroes(sdl.SDL_GPUColorTargetBlendState),
        },
    };

    const pipeline = sdl.SDL_CreateGPUGraphicsPipeline(
        device,
        &sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = vert,
            .fragment_shader = frag,
            .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .target_info = sdl.SDL_GPUGraphicsPipelineTargetInfo{
                .num_color_targets = 1,
                .color_target_descriptions = &color_targets,

                // Remaining
                .depth_stencil_format = 0,
                .has_depth_stencil_target = false,
            },
            .rasterizer_state = sdl.SDL_GPURasterizerState{
                .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
                .cull_mode = sdl.SDL_GPU_CULLMODE_NONE,

                // Remaining
                .depth_bias_clamp = 0,
                .depth_bias_constant_factor = 0,
                .depth_bias_slope_factor = 0,
                .enable_depth_bias = false,
                .enable_depth_clip = false,
                .front_face = 0,
            },
            .multisample_state = std.mem.zeroes(sdl.SDL_GPUMultisampleState), // NOTE: disables it

            // Remaining
            .vertex_input_state = std.mem.zeroes(sdl.SDL_GPUVertexInputState),
            .depth_stencil_state = std.mem.zeroes(sdl.SDL_GPUDepthStencilState),
            .props = 0,
        },
    ) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.info("{s} OK", .{str});
    return pipeline;
}

/// Destroy an SDL3 graphics pipeline
fn SDL3GPUDestroyGraphicsPipeline(device: *sdl.SDL_GPUDevice, pipeline: *sdl.SDL_GPUGraphicsPipeline) void {
    std.log.info("Destroying SDL3 graphics pipeline", .{});

    sdl.SDL_ReleaseGPUGraphicsPipeline(device, pipeline);
}

/// Bind an SDL3 pipeline to a render pass
fn SDL3GPUBindPipeline(render_pass: *sdl.SDL_GPURenderPass, pipeline: *sdl.SDL_GPUGraphicsPipeline) void {
    std.log.debug("Binding SDL3 GPU graphics pipeline", .{});

    sdl.SDL_BindGPUGraphicsPipeline(render_pass, pipeline);
}

/// Draw primatives using the bound pipeline
fn SDL3GPUDrawPrimatives(render_pass: *sdl.SDL_GPURenderPass) void {
    std.log.debug("Binding SDL3 GPU graphics pipeline", .{});

    sdl.SDL_DrawGPUPrimitives(render_pass, 3, 1, 0, 0);
}

/// Main entrypoint into the program
pub fn run(settings: ProgramSettings) SDL3Error!void {
    try SDL3Initialize();
    defer SDL3Quit();

    const device = try SDL3CreateGPUDevice(settings.shader_format, settings.enable_gpu_debug);
    defer SDL3DestroyGPUDevice(device);

    const triangle_vert = try SDL3GPUCreateShader(device, @import("triangle_vert").shader);
    defer SDL3GPUDestroyShader(device, triangle_vert);

    const triangle_frag = try SDL3GPUCreateShader(device, @import("triangle_frag").shader);
    defer SDL3GPUDestroyShader(device, triangle_frag);

    const quad_vert = try SDL3GPUCreateShader(device, @import("quad_vert").shader);
    defer SDL3GPUDestroyShader(device, quad_vert);

    const quad_frag = try SDL3GPUCreateShader(device, @import("quad_frag").shader);
    defer SDL3GPUDestroyShader(device, quad_frag);

    const window = try SDL3CreateWindow(WindowName, settings.window_w, settings.window_h);
    defer SDL3DestroyWindow(window);

    try SDL3GPUClaimWindow(device, window);
    defer SDL3GPUDestroyWindow(device, window);

    const pipeline = try SDL3GPUCreateGraphicsPipeline(device, window, triangle_vert, triangle_frag);
    defer SDL3GPUDestroyGraphicsPipeline(device, pipeline);

    outer_loop: while (true) {
        event_loop: while (SDL3PollEvent()) |event| {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => {
                    break :outer_loop;
                },
                sdl.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        sdl.SDLK_Q => {
                            break :outer_loop;
                        },
                        else => {},
                    }
                },
                else => {},
            }

            continue :event_loop;
        }

        const command_buffer = try SDL3AcquireGPUCommandBuffer(device);

        const swapchain_texture = try SDL3AcquireGPUSwapchainTextureBlocking(command_buffer, window) orelse {
            try SDL3SubmitGPUCommandBuffer(command_buffer);
            continue :outer_loop;
        };

        const color_target_infos = [_]sdl.SDL_GPUColorTargetInfo{
            sdl.SDL_GPUColorTargetInfo{
                .texture = swapchain_texture.tex,
                .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = sdl.SDL_GPU_STOREOP_STORE,
                .clear_color = ClearColor,

                // Remaining
                .mip_level = 0,
                .resolve_mip_level = 0,
                .cycle = false,
                .resolve_layer = 0,
                .resolve_texture = null,
                .cycle_resolve_texture = false,
                .layer_or_depth_plane = 0,
            },
        };

        const render_pass = try SDL3BeginGPURenderPass(command_buffer, &color_target_infos, null);

        SDL3GPUBindPipeline(render_pass, pipeline);
        SDL3GPUDrawPrimatives(render_pass);

        SDL3EndGPURenderPass(render_pass);

        try SDL3SubmitGPUCommandBuffer(command_buffer);
    }
}
