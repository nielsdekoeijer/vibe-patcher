const std = @import("std");
const sdl = @import("sdl3");

pub const SDL3Error = error{ LibraryInitialization, UnexpectedNullPointer, WindowInitialization };

pub const SDL3ShaderFormat = enum(u32) {
    spirv = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
    dxbc = sdl.SDL_GPU_SHADERFORMAT_DXBC,
    dxil = sdl.SDL_GPU_SHADERFORMAT_DXIL,
    msl = sdl.SDL_GPU_SHADERFORMAT_MSL,
    metal = sdl.SDL_GPU_SHADERFORMAT_METALLIB,
};

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

fn SDL3DestroyGPUDevice(device: *sdl.SDL_GPUDevice) void {
    std.log.info("Destroying SDL3 GPU device", .{});
    sdl.SDL_DestroyGPUDevice(device);
}

pub const ProgramSettings = struct {
    shader_format: SDL3ShaderFormat,
    enable_gpu_debug: bool,
};

pub fn run(settings: ProgramSettings) SDL3Error!void {
    try SDL3Initialize();
    defer SDL3Quit();

    const device = try SDL3CreateGPUDevice(settings.shader_format, settings.enable_gpu_debug);
    defer SDL3DestroyGPUDevice(device);

    while (true) {
    }
}
